//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <flutter_libserialport/flutter_libserialport_plugin.h>
#include <permission_handler_windows/permission_handler_windows_plugin.h>
#include <unified_esc_pos_printer/unified_esc_pos_printer_plugin_c_api.h>
#include <url_launcher_windows/url_launcher_windows.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  FlutterLibserialportPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FlutterLibserialportPlugin"));
  PermissionHandlerWindowsPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("PermissionHandlerWindowsPlugin"));
  UnifiedEscPosPrinterPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("UnifiedEscPosPrinterPluginCApi"));
  UrlLauncherWindowsRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("UrlLauncherWindows"));
}
