#!/usr/bin/env bash
# shellcheck disable=SC1003

# Based on https://gist.github.com/pkuczynski/8665367

parse_yaml() {
    local input=""
    if [ -z "${1}" ] || [ "${1}" = "-" ]; then
        input="$(cat)"
    else
        input=$(cat "${1}")
    fi

    local yaml_file=$1
    local prefix=$2
    local s
    local w
    local fs

    s='[[:space:]]*'
    w='[a-zA-Z0-9_.-]*'
    fs="$(echo @ | tr @ '\034')"

    echo "$input" |
        sed -e '/- [^\“]'"[^\']"'.*: /s|\([ ]*\)- \([[:space:]]*\)|\1-\'$'\n''  \1\2|g' |
        sed -ne '/^--/s|--||g; s|\"|\\\"|g; s/[[:space:]]*$//g;' \
            -e 's/\$/\\\$/g' \
            -e "/#.*[\"\']/!s| #.*||g; /^#/s|#.*||g;" \
            -e "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1$fs\2$fs\3|p" \
            -e "s|^\($s\)\($w\)${s}[:-]$s\(.*\)$s\$|\1$fs\2$fs\3|p" |
        awk -F"$fs" '{
        indent = length($1)/2;
        if (length($2) == 0) { conj[indent]="+";} else {conj[indent]="";}
        vname[indent] = $2;
        for (i in vname) {if (i > indent) {delete vname[i]}}
            if (length($3) > 0) {
                vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
                printf("%s%s%s%s=(\"%s\")\n", "'"$prefix"'",vn, $2, conj[indent-1], $3);
            }
        }' |
        sed -e 's/_=/+=/g' |
        awk 'BEGIN {
            FS="=";
            OFS="="
        }
        /(-|\.).*=/ {
            gsub("-|\\.", "_", $1)
        }
        { print }'
}

unset_variables() {
    # Pulls out the variable names and unsets them.
    #shellcheck disable=SC2048,SC2206 #Permit variables without quotes
    local variable_string=($*)
    unset variables
    variables=()
    for variable in "${variable_string[@]}"; do
        tmpvar=$(echo "$variable" | grep '=' | sed 's/=.*//' | sed 's/+.*//')
        variables+=("$tmpvar")
    done
    for variable in "${variables[@]}"; do
        if [ -n "$variable" ]; then
            unset "$variable"
        fi
    done
}

create_variables() {
    local yaml_file="$1"
    local prefix="$2"
    local yaml_string
    yaml_string="$(parse_yaml "$yaml_file" "$prefix")"
    unset_variables "${yaml_string}"
    eval "${yaml_string}"
}

parse_frontmatter() {
    local input=""
    if [ -z "${1}" ] || [ "${1}" = "-" ]; then
        input="$(cat)"
    else
        input=$(cat "${1}")
    fi
    local prefix="$2"
    local yaml_string
    if echo "$input" | head -1 | grep -e '^---$' >/dev/null; then
        echo "$input" | awk \
            'BEGIN {
            is_first_line=1;
            is_not_dash=0
            in_fm=0;
        }
        /^---$/ {
            if (is_first_line) {
                in_fm=1;
            }
        }
        /^(---)$/ {
            if (! is_first_line) {
                in_fm=0;
            }
            is_first_line=0;
        }
        {
            if (in_fm && is_not_dash) {
                print $0;
            }
            is_not_dash=1
        }' |
            parse_yaml - "${2}"
    fi
}

# Execute parse_frontmatter() direct from command line
if [ "-f" = "${1}" ]; then
    parse_frontmatter "${@:2}"
    exit
fi

# Execute parse_yaml() direct from command line
if [ "--debug" == "${1}" ]; then
    shift
fi
if [ "" != "${1}" ] || [ ! -t 0 ]; then
    parse_yaml "${1}" "${2}"
fi
