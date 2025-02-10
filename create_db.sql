CREATE TABLE IF NOT EXISTS "masvs_category" (
	"id"	INTEGER,
	"name"	TEXT NOT NULL,
	"url"	TEXT NOT NULL,
	PRIMARY KEY("id" AUTOINCREMENT)
);
CREATE TABLE IF NOT EXISTS "common_risk" (
	"id"	INTEGER,
	"name"	TEXT NOT NULL,
	"url"	TEXT NOT NULL,
	"masvs_category"	INTEGER NOT NULL,
	PRIMARY KEY("id" AUTOINCREMENT),
	FOREIGN KEY("masvs_category") REFERENCES "masvs_category"("id")
);
CREATE TABLE IF NOT EXISTS "app" (
            "id"	INTEGER,
            "package_id"	TEXT NOT NULL UNIQUE,
            "github_name"	TEXT NOT NULL,
            "github_repo"	TEXT NOT NULL UNIQUE,
            "github_stars"	INTEGER NOT NULL,
            "github_description"	TEXT,
            "playstore_url"	TEXT UNIQUE,
            "playstore_downloads"	INTEGER,
            "playstore_updated"	TEXT,
            "playstore_description"	TEXT,
            "path"	TEXT NOT NULL,
            "pubspec_path"	TEXT NOT NULL,
            "commit_sha"    TEXT,
            "analyzed"  BOOLEAN DEFAULT FALSE NOT NULL CHECK ("analyzed" IN (0, 1)), 
            PRIMARY KEY("id" AUTOINCREMENT)
        );
CREATE TABLE IF NOT EXISTS "api" (
	"id"	INTEGER,
	"package"	TEXT NOT NULL,
	"method"	TEXT NOT NULL,
	"dangerous"	BOOLEAN,
	"dangerous_pattern"	TEXT,
	"risk"	INTEGER,
	"lint_rule"	INTEGER,
	PRIMARY KEY("id" AUTOINCREMENT),
	FOREIGN KEY("lint_rule") REFERENCES "lint_rule"("id"),
	FOREIGN KEY("risk") REFERENCES "common_risk"("id")
);
CREATE TABLE IF NOT EXISTS "lint_rule" (
	"id"	INTEGER,
	"name"	TEXT NOT NULL UNIQUE,
	"finds_dangerous_pattern"	BOOLEAN NOT NULL DEFAULT 0,
	PRIMARY KEY("id" AUTOINCREMENT)
);
CREATE TABLE IF NOT EXISTS "finding" (
	"id"	INTEGER,
	"vulnerable"	BOOLEAN,
	"description"	TEXT,
	"location"	TEXT,
	"app"	INTEGER NOT NULL,
	"lint_rule"	INTEGER,
	PRIMARY KEY("id" AUTOINCREMENT),
	FOREIGN KEY("app") REFERENCES "app"("id"),
	FOREIGN KEY("lint_rule") REFERENCES "lint_rule"("id")
);
