# How to: 

## Add Linus (Or another user) to contributors in ur repo?

### like that
#### Contributors list
![alt text](../crap/img/contributors_preview.png)
#### Commits bar
![alt text](../crap/img/commit_bar_preview.png)

### Clone your repo

```bash
git clone https://github.com/example/coolrepo.git
```

### Set local name and mail in git config

```bash
# --local - use that config only in this repository
git config user.name "Linus Torvalds" --local
git config user.email "torvalds@linux-foundation.org" --local
```

### Make and push commit

```bash
# Create a random commit
git add modifed_file.txt
git commit -m "WOW it's Linus commit!!!"
# And push it!
git push
```

### PROFIT!

## How it work?
GitHub automatically check committers email's and connect commits with profile

## Can i set another user?
Yes. But u need user's email.

```bash
# Clone user repo
git clone https://github.com/example/coolrepo.git

# See logs
git log --pretty=full
# commit blablablacoolhash (HEAD -> main, origin/main, origin/HEAD)
# Author: Linus Torvalds <torvalds@linux-foundation.org> <-- Needed email!
# Commit: Linus Torvalds <torvalds@linux-foundation.org> <-- Needed email!
#
#    WOW it's Linus commit!
```

## Can I increase commit statistics for random person?
No. 