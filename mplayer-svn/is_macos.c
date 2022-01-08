//###############################################################################
// Author: @gubatron - January 2022
//###############################################################################
#include <stdio.h>
int main() {
#if defined(__APPLE__)
  printf("is_macos:1\n");
  return 1;
#else
  printf("is_macos:0\n");
  return 0;
#endif
}
