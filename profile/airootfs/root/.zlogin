# Root's console login on the live medium.
if [[ -z ${HEXFORGE_GREETED-} ]]; then
    export HEXFORGE_GREETED=1
    /usr/local/bin/hexforge-welcome 2>/dev/null || true
fi
