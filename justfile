import 'plugin-dev/release.just'

precommit:
	jq . .claude-plugin/plugin.json > /dev/null
	jq . hooks/hooks.json > /dev/null
	bash -n scripts/*.sh
	shellcheck scripts/*.sh tests/*.sh
	bash tests/hook-test.sh
