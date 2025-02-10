# "Exploring Dangerous Code Patterns in Flutter Android Apps" Master thesis - Experimental Code

## Repo structure

- `create_db.sql`: SQLite schema
- `fetch_repo.py`: dataset creation script 
  - requires read-only GitHub PAT in `GITHUB_TOKEN` environment variable
  - uses GitHub API to search for Flutter Android app repos
  - saves snapshots as pickle files, exports final result into SQLite. 
- `reposcanner.py`: instrument lint rules in `thesis_lints/` to scan apps for API usages
  - requires Flutter SDK 3.27.0 and SDK 3.7.2, download here: https://docs.flutter.dev/release/archive
  - requires path configuration in `reposcanner.json` file
    - path for SQLite database
    - path for GitHub repos
    - path to the `bin` directory of both Flutter SDKs
  - reads repos from `app` table from SQLite
  - clones all repos if they don't exist yet
  - runs lint rules on all repos using a modified version of the [custom_lint](https://pub.dev/packages/custom_lint) package. Modified version is located here: [realansgar/dart_custom_lint: feat_workspace](https://github.com/realansgar/dart_custom_lint/tree/feat_workspace)
  - saves findings in SQLite in `finding` table
- `thesis_lints/`: lint rules that detect APIs and 3 dangerous code patterns

## Dataset

The dataset and API usage findings are available in the `dangerous_apis.db` SQLite database. The schema is in `create_db.sql`. The dataset includes 851 apps, of which 144 are Play Store-listed apps. The source code of apps can be downloaded from GitHub with the included GitHub URL and commit hash. 747 apps were successfully analyzed and the results saved in the `finding` table.
