SHELL := /bin/bash
MAKESHFILE := Makefile.sh
MAX_DEPTH := 5

.PHONY: ANY
.DEFAULT_GOAL := help
Makefile: ;

MODULE_LIST := find . -type f -maxdepth $(MAX_DEPTH) -name $(MAKESHFILE) 2>/dev/null -exec dirname {} \;
define MODULE_INVOKE
cd "$${MODULE}"; . $(MAKESHFILE) > /dev/null 2>&1
$(1)
cd - 2>&1 > /dev/null
endef
TARGET_LIST := declare -F | cut -d' ' -f3 | grep -vE "^_"
define USAGE
cat <<'USAGE'
Usage:
?                      : List available modules
all                    : Build all modules
[module]// || [module] : Build [module]
[module]//?            : List targets in [module]
[module]//[target]?    : Show target implementation
help                   : Print this message
USAGE
endef
define VARHELPER
function $(1)() {
	local key="$${1}"
	shift
	for arg in "$${@}"; do
		if [[ "$${arg}" == "$${key}="* ]]; then
			$(2)
			return 0
		fi
	done
	return 1
}
endef
define MAKESHPARSE
$(call VARHELPER,_kv,echo "$${key}=$${arg#*=}")
$(call VARHELPER,_v,echo "$${arg#*=}")
COMMAND="$${1}"
shift
if [[ -z "$${COMMAND}" || "$${COMMAND}" = "help" ]]; then
	$(USAGE)
elif [[ "$${COMMAND}" = "?" ]]; then
	$(MODULE_LIST) | sed -E 's|^\./||; s|^\.$$|//|'
elif [[ "$${COMMAND}" = "all" ]]; then
	$(MODULE_LIST) | while IFS= read MODULE; do
		$(call MODULE_INVOKE,
			init "$${@}" < /dev/tty || break
		)
	done
else
	if [[ "$${COMMAND}" == *"//"* ]]; then
		MODULE="$${COMMAND%%//*}"
		TARGET="$${COMMAND#*//}"
	else
		MODULE="$${COMMAND}"
	fi
	MODULE="$${MODULE:-.}"
	TARGET="$${TARGET:-init}"
	if [ -f "$${MODULE}/$(MAKESHFILE)" ]; then
		$(call MODULE_INVOKE,
			if [ "$${TARGET}" = "?" ]; then
				$(TARGET_LIST)
			elif [[ "$${TARGET}" == *\? ]]; then
				type "$${TARGET%?}" | grep -vE "^$${TARGET} is a function$$"
			else
				if $(TARGET_LIST) | grep -q "$${TARGET}"; then
					"$${TARGET}" "$${@}"
				else
					echo "Error: Target not implemented: $${MODULE}//$${TARGET}" >&2
				fi
			fi
		)
	else
		echo -e "Error: Module not found: $${MODULE}\n" >&2
		$(USAGE)
	fi
fi
endef

export MAKESHPARSE
%: ANY
	@$(SHELL) <(echo "$$MAKESHPARSE") $(@) $(MAKEOVERRIDES)

make.sh: ANY
	@echo -e "#!/usr/bin/env bash\n\n$$MAKESHPARSE\n" > $@
	@chmod +x $@
