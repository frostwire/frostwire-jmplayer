#include <stdio.h>

int main() {
#if defined(__linux__) && !defined(__APPLE__)
  return 0;
#else
  return 1;
#endif
}
