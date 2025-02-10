import os, json, sqlite3, tempfile, shutil
from os.path import realpath, isfile, dirname
from subprocess import CalledProcessError, check_output, run, PIPE
from argparse import ArgumentParser, BooleanOptionalAction
from itertools import product
from copy import deepcopy

from tqdm import tqdm
import yaml


def clone_repo(app: sqlite3.Row, repo_dir: str, commit_sha: str = None):
    assert app["github_repo"].startswith("https://github.com/")
    check_output(["rm", "-rf", repo_dir])
    check_output(["git", "clone", "--recurse-submodules", "--end-of-options", app["github_repo"], repo_dir])
    if commit_sha:
        check_output(["git", "-C", repo_dir, "fetch", "origin", commit_sha])
        check_output(["git", "-C", repo_dir, "checkout", commit_sha])
    commit_sha = check_output(["git", "-C", repo_dir, "rev-parse", "HEAD"], encoding="utf-8").strip()
    return commit_sha

def setup_analyzer(app: sqlite3.Row, repo_dir: str, flutter_3_7_12: str, flutter_3_27_0: str, lint_rules: list[str]):
    check_output(["git", "-C", repo_dir, "reset", "--hard"])
    check_output(["git", "-C", repo_dir, "clean", "-fxd"])

    app_path = f"{repo_dir}/{app['path']}"
    pubspec_path = f"{repo_dir}/{app['pubspec_path']}"
    with open(pubspec_path) as f:
        pubspec = yaml.safe_load(f)
    sdk_constraint = pubspec.get("environment", {}).get("sdk", "")
    if (not sdk_constraint):
        sdk_constraint = ">=2.0.0 <3.0.0"
        pubspec["environment"] = {"sdk": sdk_constraint}
        with open(pubspec_path, "w") as f:
            yaml.safe_dump(pubspec, f)
    
    if "git://" in str(pubspec):
        raise Exception("cannot clone git via SSH")
    
    analysis_options = {}
    try:
        with open(f"{app_path}/analysis_options.yaml") as f:
            analysis_options = yaml.safe_load(f) or {}
    except FileNotFoundError:
        pass
    with open(f"{app_path}/analysis_options.yaml", "w") as f:
        excludes = list(set(["test/**"] + (analysis_options.get("analyzer", {}).get("exclude", []) or [])))
        analysis_options = {"analyzer": {"plugins": ["custom_lint"], "exclude": excludes}}
        if lint_rules:
            analysis_options["custom_lint"] = {"enable_all_lint_rules": False, "rules": lint_rules}
        yaml.safe_dump(analysis_options, f)

    stderr_output = ""
    for (use_old_flutter, override_deps) in product((False, True), repeat=2):
        try:
            env = os.environ.copy()
            pubspec_copy = deepcopy(pubspec)
            if use_old_flutter:
                env["PATH"] = f"{flutter_3_7_12}:{os.environ['PATH']}"
            else:
                env["PATH"] = f"{flutter_3_27_0}:{os.environ['PATH']}"
            if override_deps:
                if use_old_flutter:
                    added_overrides = {
                        # required by flutter_localizations from Flutter SDK 3.7.2
                        "intl": "0.17.0",
                        # required by flutter_test from Flutter SDK 3.7.2
                        "test_api": "0.4.16",
                    }
                else:
                    added_overrides = {
                        # required by flutter from Flutter SDK 3.27.0
                        "meta": "1.15.0",
                        # required by flutter_localizations from Flutter SDK 3.27.0
                        "intl": "0.19.0",
                        # required by flutter_test from Flutter SDK 3.27.0
                        "collection": "1.19.0",
                        "material_color_utilities": "0.11.1",
                    }
                dependency_overrides = pubspec.get("dependency_overrides", {}) or {}
                dependency_overrides.update(added_overrides)
                pubspec_copy["dependency_overrides"] = dependency_overrides
            with open(pubspec_path, "w") as f:
                yaml.safe_dump(pubspec_copy, f)
            run(["dart", "pub", f"--directory={app_path}", "get"], stdout=PIPE, stderr=PIPE, env=env, check=True, encoding='utf-8')
            return
        except CalledProcessError as e:
            stderr_output += e.stderr
    raise Exception(stderr_output)
            

def run_analyzer(app: sqlite3.Row, shell_dir: str, repo_dir: str, flutter_dir: str):
    app_path = f"{repo_dir}/{app['path']}"
    os.chdir(shell_dir)
    env = os.environ.copy()
    env["PATH"] = f"{flutter_dir}:{os.environ['PATH']}"

    output = run(["dart", "run", "custom_lint", "--format=json", f"--directory={app_path}"], stdout=PIPE, env=env).stdout
    output_dict = json.loads(output)
    return output_dict["diagnostics"]

def prepare_custom_lint_shell_dir(thesis_lints_dir: str, flutter_dir: str):
    env = os.environ.copy()
    env["PATH"] = f"{flutter_dir}:{os.environ['PATH']}"
    shell_dir = tempfile.mkdtemp(prefix="reposcanner")
    with open(f"{shell_dir}/pubspec.yaml", "w") as f:
        f.write(f"""
name: custom_lint_shell
description: A shell for custom_lint
version: 0.0.1
publish_to: 'none'
environment:
  sdk: ^3.0.0
dependencies:
  custom_lint:
  thesis_lints:
    path: {thesis_lints_dir}
dependency_overrides:
  custom_lint:
    git:
      url: "https://github.com/realansgar/dart_custom_lint.git"
      path: packages/custom_lint/
      ref: feat_workspace
  custom_lint_builder:
    git:
      url: "https://github.com/realansgar/dart_custom_lint.git"
      path: packages/custom_lint_builder/
      ref: feat_workspace
""")
    check_output(["dart", "pub", f"--directory={shell_dir}", "get"], env=env)
    return shell_dir

def download_analyze_apps(connection: sqlite3.Connection, config: dict, args):
    lint_rules = None # == use all lint_rules
    if args.rules:
        rule_tuple = tuple(map(int, args.rules.split(',')))
        lint_rule_cursor = connection.execute(f"SELECT name FROM lint_rule WHERE id IN ({','.join('?' * len(rule_tuple))})", rule_tuple)
        lint_rules = [lint_rule['name'] for lint_rule in lint_rule_cursor.fetchall()]

    cursor = connection.execute("SELECT * FROM app ORDER BY github_stars DESC LIMIT ?", (args.limit,))
    apps: list[sqlite3.Row] = cursor.fetchall()
    shell_dir = prepare_custom_lint_shell_dir(config["thesis_lints_dir"], config["flutter_3_27_0"])
    for app in tqdm(apps):
        repo_dir = f"{config['repos_dir']}/{app['id']}"
        if args.force_clone or not isfile(f"{repo_dir}/{app['pubspec_path']}"):
            try:
                commit_sha = clone_repo(app, repo_dir, app["commit_sha"])
                connection.execute("UPDATE app SET commit_sha = ? WHERE id = ?", (commit_sha, app["id"]))
            except Exception as e:
                print(f"Failed to clone {app['github_repo']}: {e}")
                continue
        if args.force_analyze or not app["analyzed"]:
            try:
                setup_analyzer(app, repo_dir, config['flutter_3_7_12'], config['flutter_3_27_0'], lint_rules)
            except Exception as e:
                print(f"failed to setup app: {app['id']} {app['github_repo']}: {e}")
                continue
            try:
                findings = run_analyzer(app, shell_dir, repo_dir, config['flutter_3_27_0'])
            except Exception as e:
                print(f"Failed to analyze app {app['id']} {app['github_repo']}: {e}")
                continue

            # clean up old, unconfirmed findings that are not manually added (lint_rule IS NULL for manual findings)
            if args.delete_findings:
                connection.execute("DELETE FROM finding WHERE app = ? AND vulnerable IS NULL AND lint_rule IS NOT NULL", (app["id"],))
            
            connection.executemany("""
                INSERT INTO finding (description, location, app, lint_rule) VALUES (
                    ?, ?, ?,
                    (SELECT id FROM lint_rule WHERE lint_rule.name = ? COLLATE NOCASE)
                )
                """,
                [(finding["problemMessage"], json.dumps(finding["location"], indent=4), app["id"], finding["code"]) for finding in findings if lint_rules is None or finding["code"] in map(str.lower, lint_rules)]
            )
            connection.execute("UPDATE app SET analyzed = TRUE WHERE id = ?", (app["id"],))
    shutil.rmtree(shell_dir)

        
def main():
    argparser = ArgumentParser()
    argparser.add_argument("config")
    argparser.add_argument("--clone", dest="force_clone", action=BooleanOptionalAction, help="force reclone of all apps")
    argparser.add_argument("--analyze", dest="force_analyze", action=BooleanOptionalAction, help="force reanalysis of all apps")
    argparser.add_argument("--delete-findings", dest="delete_findings", action=BooleanOptionalAction, help="delete old findings before analysis")
    argparser.add_argument("-r", "--rules", type=str, default="", help="comma-separated list of lint_rule IDs from attached database. analysis will be limited to those rules")
    argparser.add_argument("-l", "--limit", type=int, default=-1, help="limit the number of apps to analyze, ordered by github_stars")
    args = argparser.parse_args()

    with open(args.config) as f:
        config = json.load(f)
        assert list(config.keys()) == ["database", "repos_dir", "flutter_3_7_12", "flutter_3_27_0"]
        config = {k: realpath(v, strict=True) for k, v in config.items()}

    config["thesis_lints_dir"] = realpath(f"{dirname(__file__)}/thesis_lints", strict=True)
    connection = sqlite3.connect(config["database"], autocommit=True)
    connection.row_factory = sqlite3.Row
    with open("create_db.sql") as f:
        create_db_script = f.read()
    connection.executescript(create_db_script)

    os.environ["GIT_TERMINAL_PROMPT"] = "0"

    download_analyze_apps(connection, config, args)

    connection.close()

if __name__ == "__main__":
    main()
