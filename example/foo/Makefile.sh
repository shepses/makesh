function init() {
    echo "Hello from example/foo"
}

function test() {
    echo "Testing module ..."
    echo done
    echo $(_kv "var" "$@")
    echo $(_v "var" "$@")
}