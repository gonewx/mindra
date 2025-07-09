#include "my_application.h"
#include <X11/Xlib.h>

int main(int argc, char** argv) {
  // Initialize X11 threading support
  XInitThreads();
  
  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
