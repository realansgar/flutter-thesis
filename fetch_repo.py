#!/usr/bin/env python3

from typing import Optional
from tqdm import tqdm
from github import Github, Auth
from github.Repository import Repository
from github.GitTree import GitTree
from github.ContentFile import ContentFile
from subprocess import check_output
from datetime import datetime
import pickle, os, re, csv
from argparse import ArgumentParser
from dataclasses import dataclass
from requests import session
from bs4 import BeautifulSoup
from time import sleep
import sqlite3

PLAYSTORE_URL = "https://play.google.com/store/apps/details"
FDROID_URL = "https://f-droid.org/en/packages/"

@dataclass
class MyApp:
    path: str
    pubspec: ContentFile
    android_manifest: ContentFile
    app_identifier: Optional[str] = None
    playstore_url: Optional[str] = None
    fdroid_url: Optional[str] = None
    playstore_downloads: Optional[int] = None
    playstore_description: Optional[str] = None
    playstore_updated: Optional[str] = None

@dataclass
class MyRepository:
    repository: Repository
    git_tree: GitTree = None
    is_flutter: bool = False
    pubspecs: Optional[list[ContentFile]] = None
    android_manifests: Optional[list[ContentFile]] = None
    build_gradle_files: Optional[list[ContentFile]] = None
    apps: Optional[list[MyApp]] = None


def get_pubspecs_manifests(repo: MyRepository):
    repo.pubspecs = []
    repo.android_manifests = []
    for file in repo.git_tree.tree:
        filename = os.path.basename(file.path)
        if filename == "pubspec.yaml":
            repo.pubspecs.append(repo.repository.get_contents(file.path))
        elif filename == "AndroidManifest.xml":
            repo.android_manifests.append(repo.repository.get_contents(file.path))

def get_build_gradle_files(repo: MyRepository):
    repo.build_gradle_files = []
    for file in repo.git_tree.tree:
        filename = os.path.basename(file.path)
        if filename == "build.gradle" or filename == "build.gradle.kts":
            repo.build_gradle_files.append(repo.repository.get_contents(file.path))

def get_app_identifiers(repo: MyRepository):
    repo.app_identifiers = []
    for build_gradle_file in repo.build_gradle_files:
        m = re.search(r'''applicationId\s+(?:=\s*)?["']([a-zA-Z0-9_.]+)["']''', build_gradle_file.decoded_content.decode())
        try:
            for app in repo.apps:
                if os.path.commonpath([app.path, build_gradle_file.path]) == app.path:
                    app.app_identifier = m[1]
        except:
            pass


def check_flutter(repos: list[MyRepository]):
    print(f"checking {len(repos)} repos")
    for repo in tqdm(repos):
        try:
            if repo.pubspecs is None or repo.android_manifests is None:
                get_pubspecs_manifests(repo)
    
            repo.apps = []
            for pubspec in repo.pubspecs:
                if not re.search(r"flutter:\n\s+sdk:\s*flutter", pubspec.decoded_content.decode()):
                    continue

                pubspec_dir = os.path.dirname(pubspec.path)

                for android_manifest in repo.android_manifests:
                    if os.path.commonpath([pubspec_dir, android_manifest.path]) != pubspec_dir:
                        continue
                    if "android.intent.action.MAIN" not in android_manifest.decoded_content.decode():
                        continue
                    if "example/" in android_manifest.path: 
                        continue
                    repo.is_flutter = True
                    repo.apps.append(MyApp(pubspec_dir, pubspec, android_manifest))

        except Exception as e:
            print(e)
    print(f"flutter repos: {len([repo for repo in repos if repo.is_flutter])}")
    return repos


def filter(repos: list[MyRepository]):
    print(f"checking {len(repos)} repos")
    filtered_repos = []
    for repo in tqdm(repos):
        if not repo.is_flutter:
            continue

        filtered_apps: list[MyApp] = []
        for app_cand in repo.apps:
            if "example/" in app_cand.path:
                continue
            if app_cand.app_identifier is None:
                get_app_identifiers(repo)
            if not app_cand.app_identifier:
                continue
            if "example" in app_cand.app_identifier:
                continue
            if any(app for app in filtered_apps if app.app_identifier == app_cand.app_identifier):
                continue
            filtered_apps.append(app_cand)
        
        if len(filtered_apps) != 1:
            continue
        repo.apps = filtered_apps
        filtered_repos.append(repo)
    return filtered_repos

            

def check_stores(repos: list[MyRepository]):
    flutter_repos = [repo for repo in repos if repo.is_flutter]
    print(f"checking {len(flutter_repos)} repos")
    playstore_session = session()
    fdroid_session = session()
    failed_repos = []
    for repo in tqdm(flutter_repos):
        try:
            if repo.build_gradle_files is None:
                get_build_gradle_files(repo)
            for app in repo.apps:
                if app.app_identifier is None:
                    get_app_identifiers(repo)
                if not app.app_identifier:
                    continue
                if app.playstore_url is None:
                    res = playstore_session.get(PLAYSTORE_URL, params={"id": app.app_identifier})
                    sleep(0.1)
                    if res.ok:
                        app.playstore_url = res.url
                    elif res.status_code == 404:
                        pass
                    elif res.status_code == 500:
                        failed_repos.append(repo)
                    else:
                        print(res.status_code, res.text, res.url)
                if app.fdroid_url is None:
                    res = fdroid_session.get(FDROID_URL + app.app_identifier)
                    if res.ok:
                        app.fdroid_url = res.url
                    elif res.status_code == 404:
                        pass
                    else:
                        print(res.status_code, res.text, res.url)
        except Exception as e:
            print(e)
    
    # retry if rate-limiting leads to errors
    sleep(60)
    if len(failed_repos) > 0:
        check_stores(failed_repos)
    return repos


def check_playstore_metadata(repos: list[MyRepository]):
    playstore_apps = [app for repo in repos for app in repo.apps if app.playstore_url]
    playstore_session = session()
    for app in tqdm(playstore_apps):
        try:
            res = playstore_session.get(app.playstore_url)
            if res.ok:
                soup = BeautifulSoup(res.text)
                m = re.search(r"([\d]+?)([KMB]?)\+Downloads", soup.text)
                downloads = int(m[1])
                if m[2] == "K":
                    downloads *= int(1e3)
                elif m[2] == "M":
                    downloads *= int(1e6)
                elif m[2] == "B":
                    downloads *= int(1e9)
                app.playstore_downloads = downloads
                m = re.search(r"About this (?:app|game)arrow_forward(.+?)Updated on(\w{3} \d{1,2}, \d{4})", soup.text)
                app.playstore_description = m[1]
                app.playstore_updated = m[2]
            elif res.status_code == 404:
                print(app.playstore_url, "404 error")    
        except Exception as e:
            print(app.playstore_url, e)
    return repos


def export_csv(repos: list[MyRepository], name: str):
    with open(name, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["name", "url", "stars", "github_description", "app_identifier", "playstore_url", "playstore_downloads", "playstore_updated", "playstore_description"])
        rows = [[
            repo.repository.full_name,
            repo.repository.html_url,
            repo.repository.stargazers_count,
            repo.repository.description,
            app.app_identifier,
            app.playstore_url,
            app.playstore_downloads,
            app.playstore_updated,
            app.playstore_description

        ] for repo in repos for app in repo.apps]
        w.writerows(rows)


def export_sqlite(repos: list[MyRepository], name: str):
    with open("create_db.sql") as f:
        create_db_script = f.read()
    connection = sqlite3.connect(name, autocommit=True)
    connection.executescript(create_db_script)

    rows = [[
        repo.repository.full_name,
        repo.repository.html_url,
        repo.repository.stargazers_count,
        repo.repository.description,
        app.app_identifier,
        app.path,
        app.pubspec.path,
        app.playstore_url,
        app.playstore_downloads,
        app.playstore_updated,
        app.playstore_description
    ] for repo in repos for app in repo.apps]
    connection.executemany("""
        REPLACE INTO app (
            "github_name",
            "github_repo",
            "github_stars",
            "github_description",
            "package_id",
            "path",
            "pubspec_path",
            "playstore_url",
            "playstore_downloads",
            "playstore_updated",
            "playstore_description"
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """, 
        rows
    )
    connection.close()


def dedup_repos(repos: list[Repository]) -> list[Repository]:
    seen = set()
    repos_dedup = []
    for repo in repos:
        if repo.full_name not in seen:
            repos_dedup.append(repo)
            seen.add(repo.full_name)
    return repos_dedup

def save_repos(repos, name):
    with open(name, "wb") as f: 
        pickle.dump(repos, f)

def load_repos(path) -> list[MyRepository]:
    with open(path, "rb") as f:
        return pickle.load(f)


def fetch_github_repos(min_stars):
    cur_min_stars = min_stars
    repos = []
    while True:
        repos_paginated = G.search_repositories("", sort="stars", order="asc", language="Dart", stars=f">={cur_min_stars}")
        repos.extend(tqdm(repos_paginated))
        print(f"{repos_paginated.totalCount=}")
        print(f"{len(repos)=}")
        if (repos_paginated.totalCount > 1000):
            cur_min_stars = repos[-1].stargazers_count
        else:
            break
    repos = dedup_repos(repos)
    repos = [MyRepository(repo, repo.get_git_tree(repo.default_branch, recursive=True)) for repo in tqdm(repos)]
    print(f"found repos: {len(repos)}")
    return repos
    


if __name__ == '__main__':
    GH_TOKEN = os.getenv("GITHUB_TOKEN")
    G = Github(auth=Auth.Token(GH_TOKEN), per_page=100)

    argparser = ArgumentParser()
    argparser.add_argument("command", choices=["fetch", "check", "stores", "play_meta", "filter", "export_csv", "export_sqlite", "pipeline"])
    argparser.add_argument("args", nargs="*")
    argparser.add_argument("-o", "--output")

    args = argparser.parse_args()
    output_name = args.output

    if args.command == "fetch":
        min_stars = args.args[0]
        repos = fetch_github_repos(min_stars)
        if not output_name:
            d = datetime.now().replace(microsecond=0).isoformat()
            output_name = f"repos-{min_stars}-stars-{d}.pickle"
        save_repos(repos, output_name)
    elif args.command == "check":
        path = args.args[0]
        repos = load_repos(path)
        flutter_repos = check_flutter(repos)
        if not output_name:
            output_name, _ = os.path.splitext(os.path.basename(path))
            output_name += "-flutter.pickle"
        save_repos(repos, output_name)
    elif args.command == "stores":
        path = args.args[0]
        repos = load_repos(path)
        flutter_repos = check_stores(repos)
        if not output_name:
            output_name, _ = os.path.splitext(os.path.basename(path))
            output_name += "-stores.pickle"
        save_repos(repos, output_name)
    elif args.command == "play_meta":
        path = args.args[0]
        repos = load_repos(path)
        flutter_repos = check_playstore_metadata(repos)
        if not output_name:
            output_name, _ = os.path.splitext(os.path.basename(path))
            output_name += "-play_meta.pickle"
        save_repos(repos, output_name)
    elif args.command == "filter":
        path = args.args[0]
        repos = load_repos(path)
        filtered_repos = filter(repos)
        if not output_name:
            output_name, _ = os.path.splitext(os.path.basename(path))
            output_name += "-filtered.pickle"
        save_repos(filtered_repos, output_name)
    elif args.command == "export_csv":
        path = args.args[0]
        repos = load_repos(path)
        if not output_name:
            output_name, _ = os.path.splitext(os.path.basename(path))
            output_name += ".csv"
        export_csv(repos, output_name)
    elif args.command == "export_sqlite":
        path = args.args[0]
        repos = load_repos(path)
        if not output_name:
            output_name, _ = os.path.splitext(os.path.basename(path))
            output_name += ".db"
        export_sqlite(repos, output_name)
    elif args.command == "pipeline":
        min_stars = args.args[0]
        output_db = args.args[1]
        repos = fetch_github_repos(min_stars)
        repos = check_flutter(repos)
        repos = filter(repos)
        repos = check_stores(repos)
        repos = check_playstore_metadata(repos)
        if not output_name:
            d = datetime.now().replace(microsecond=0).isoformat()
            output_name = f"repos-{min_stars}-stars-{d}.pickle"
        save_repos(repos, output_name)
        export_sqlite(repos, output_db)

