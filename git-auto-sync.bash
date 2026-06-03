#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

if [[ ${AUTO_SYNC_DEBUG:-} == 'true' ]]; then
	echo "AUTO_SYNC_HOOK_NAME: ${AUTO_SYNC_HOOK_NAME:?}"
	set -o xtrace
fi

function main {
	# Intentionally global
	last_reflog_entry="$(git reflog show --max-count 1)"
	pull_rebase_regex='^.*: (pull|rebase)( .*)?: .+'
	last_commit="$(get_last_commit)"

	# We'll consider the repository synced with any commit made locally.
	if
		{
			[[ $AUTO_SYNC_HOOK_NAME == 'post-commit' ]] &&
				# post-commit hooks triggered during a pull/rebase shouldn't count
				[[ ! $last_reflog_entry =~ $pull_rebase_regex ]]
		} ||
			{
				[[ $AUTO_SYNC_HOOK_NAME == 'post-rewrite' ]] &&
					[[ $1 == 'amend' ]]
			}
	then
		track_last_synced_commit
		exit
	fi

	should_sync="$(should_sync "$@")"

	if [[ ${AUTO_SYNC_CHECK_ONLY:-} == 'true' ]]; then
		if [[ $should_sync == 'true' ]]; then
			exit 0
		else
			exit 1
		fi
	fi

	if [[ $should_sync == 'true' ]]; then
		# Even if the sync doesn't succeed, we still want to consider the repository
		# synced against the current commit since the user will probably fix whatever
		# wasn't working and rerun the sync.
		trap track_last_synced_commit EXIT

		local -a sync_command
		local seen_delimiter='false'
		for arg in "$@"; do
			if [[ $seen_delimiter == 'true' ]]; then
				sync_command+=("$arg")
			elif [[ $arg == '--' ]]; then
				seen_delimiter='true'
			fi
		done

		AUTO_SYNC_LAST_COMMIT="$last_commit" "${sync_command[@]}"
	fi
}

function track_last_synced_commit {
	local last_commit_path
	last_commit_path="$(get_last_commit_path)"
	# By only tracking the file tree for a commit, our cache won't get invalidated by
	# changes to metadata like the commit message.
	git rev-parse 'HEAD^{tree}' >"$last_commit_path"
}

function get_last_commit_path {
	local git_directory
	git_directory="$(git rev-parse --absolute-git-dir)"
	echo "$git_directory/info/auto-sync-last-commit"
}

function get_last_commit {
	local last_commit_path
	last_commit_path="$(get_last_commit_path)"
	if [[ -e $last_commit_path ]]; then
		echo "$(<"$last_commit_path")"
	fi
}

function should_sync {
	local should_sync='true'

	# If there are no differences between the last commit we synced with and the
	# current one, then we shouldn't sync.
	if
		[[ -n $last_commit ]] &&
			git diff --exit-code --quiet "$last_commit" HEAD
	then
		should_sync='false'
	fi

	local should_allow_all_branches
	should_allow_all_branches="$(safe_git_config_get 'auto-sync.allow.all')"
	local is_head_in_default_branch
	is_head_in_default_branch="$(is_head_in_default_branch)"
	local -r pull_regex='^.*: pull( .*)?: .+'
	if
		[[ $should_allow_all_branches != 'true' && $is_head_in_default_branch != 'true' ]] &&
			! {
				[[ $AUTO_SYNC_HOOK_NAME == 'post-merge' || $AUTO_SYNC_HOOK_NAME == 'post-rewrite' ]] &&
					[[ ! $last_reflog_entry =~ $pull_regex ]]
			}
	then
		should_sync='false'
	fi

	case "${AUTO_SYNC_HOOK_NAME:?}" in
		'post-commit')
			should_sync='false'
			;;
		'post-merge' | 'post-rewrite')
			# There's nothing to do in this case
			;;
		'post-checkout')
			if
				# We should only sync if this is a branch/commit checkout and not a file
				# checkout. The documentation says the third argument to the hook is '1'
				# if it's a branch checkout, but this seems to include checkouts to
				# arbitrary commits as well.
				(($3 != 1)) ||
					# Don't run when we're in the middle of a pull/rebase,
					# post-merge/post-rewrite will run when the pull/rebase is finished.
					[[ $last_reflog_entry =~ $pull_rebase_regex ]] ||
					# If the destination commit has been pushed to the default branch, I
					# assume the user is going through the history to debug. As such, we
					# shouldn't sync.
					git merge-base --is-ancestor "$2" origin
			then
				should_sync='false'
			fi
			;;
		*)
			echo "auto-sync: Error, invalid AUTO_SYNC_HOOK_NAME: $AUTO_SYNC_HOOK_NAME" >&2
			exit 1
			;;
	esac

	echo "$should_sync"
}

function is_head_in_default_branch {
	local default_branch
	default_branch="$(get_default_branch)"

	if git merge-base --is-ancestor HEAD "$default_branch"; then
		echo 'true'
	else
		echo 'false'
	fi
}

function get_default_branch {
	local default_branch_path
	default_branch_path="$(git symbolic-ref refs/remotes/origin/HEAD)"
	# This gets the characters after the last '/'. `default_branch_path` will resemble
	# 'refs/remotes/origin/master' so this would return 'master'.
	echo "${default_branch_path##*/}"
}

function safe_git_config_get {
	# git exits with 1 if you try to get the value of a setting that isn't set, but we
	# don't want the script to exit if that happens.
	set +o errexit
	git config get "$@"
	local exit_code=$?
	set -o errexit
	if ((exit_code == 1)); then
		return 0
	else
		return "$exit_code"
	fi
}

main "$@"
