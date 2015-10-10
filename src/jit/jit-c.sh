# JIT support for C99 programs
# Calling convention for these is like this:
#
# jit_program=$(jit_c <<'EOF'
# #include <stdio.h>
# int main() {
#   printf("hello world\n");
#   return 0;
# }
# EOF
# )
#
# $jit_program "$@"             # to execute the program
#
# Later on, you can free the jit context like this:
# jit_c_free $jit_program

jit_c_index=0
jit_c() {
  tmpdir
  jit_c_index=$((jit_c_index + 1))
  jit_c_source="$self_tmpdir/jit-c-$jit_c_index.c"
  cat > "$jit_c_source"
  c99 "$jit_c_source" -o "${jit_c_source%.c}"
  verb "${jit_c_source%.c}"
}

jit_c_free() rm "$1" "$1.c"
