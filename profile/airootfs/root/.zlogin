# Root's console login on the live medium.
if [[ -z ${UNDRABYTE_GREETED-} ]]; then
    export UNDRABYTE_GREETED=1
    /usr/local/bin/undrabyte-welcome 2>/dev/null || true
fi
