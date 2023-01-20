their_branch=$1
commit_msg=$2

help() {
	echo $1
	echo --- HELP ---
	echo - Rebase 
	echo Use the script like so:
	echo "source rebase.sh branchMergingInto CommitMessage"
	echo ''
	return 0;
}

becho() {
bold=$(tput bold)
normal=$(tput sgr0)
echo ${bold}$1${normal}
}

if [ -z "$their_branch" ]
then
	help 'You need to specify a branch'
	return 0
fi
if [ -z "$commit_msg" ]
then
	if [ $(git -C ./ rev-parse >/dev/null 2>&1 ) ]; then
		help 'You are not in a repository'
		return 0
	fi
        echo "You didnt specify a commit message, do you want to use the default ($(git branch --show-current))"
	select yn in "Yes" "No"; do
    		case $yn in
        		Yes ) commit_msg=$(git branch --show-current); break;;
        		No ) help && return 0; exit;;
    		esac
	done
fi

echo "You are currently on branch $(git branch --show-current), Is this the correct branch, and have you pushed your changes?"
select yn in "Yes" "No"; do
	case $yn in
		Yes ) break;;
		No ) return 0; exit;;
        esac
done

your_branch=$(git branch --show-current)

becho '-- Fetching latest from remote --'
gco ${their_branch}
# git checkout development
gup
# git fetch && git rebase
gco ${your_branch}
# git checkout your-branch
becho '-- Reseting local changes against remote --'
git reset $(git merge-base ${their_branch} $(git branch --show-current))
becho '-- Staging and commiting changes --'
ga .
# git add .

gcmsg ${commit_msg}
# git commit -m ${commit-msg}

becho '-- Fetching latest from remote --'
gco ${their_branch}
gup
gco ${your_branch}
becho '-- Rebasing --'
grb ${their_branch}
# git rebase development
becho '-- Remember to force push --'
