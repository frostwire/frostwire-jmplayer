//###############################################################################
// Author: @gubatron - January 2022
//###############################################################################
#include <stdio.h>
int main() {
#if defined(_WIN64)
  printf("is_windows:1\n");
  return 1;
#else
  printf("is_windows:0\n");
  return 0;
#endif
}
