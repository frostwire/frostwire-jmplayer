//###############################################################################
// Author: @gubatron - September 2019
//###############################################################################
#include <stdio.h>
int main() {
#if defined(__linux__)
  printf("is_linux:1\n");  
  return 1;
#else
  printf("is_linux:0\n");
  return 0;
#endif
}
