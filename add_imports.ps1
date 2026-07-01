$files = @(
  "lib/features/dashboard/presentation/pages/task_config_screen.dart",
  "lib/features/profile/presentation/pages/profile_setup_screen.dart",
  "lib/features/profile/presentation/pages/user_profile_screen.dart",
  "lib/features/mechanic/presentation/pages/mechanic_dashboard_screen.dart",
  "lib/features/mechanic/presentation/pages/vehicle_search_screen.dart",
  "lib/features/mechanic/presentation/pages/initiate_service_screen.dart",
  "lib/features/mechanic/presentation/pages/workshop_settings_screen.dart",
  "lib/features/mechanic/presentation/pages/mechanic_reviews_screen.dart",
  "lib/features/admin/presentation/pages/admin_dashboard_screen.dart",
  "lib/features/admin/presentation/pages/admin_usuarios_screen.dart",
  "lib/features/admin/presentation/pages/admin_talleres_screen.dart",
  "lib/features/admin/presentation/pages/admin_resenias_screen.dart",
  "lib/features/admin/presentation/pages/admin_logs_screen.dart",
  "lib/features/admin/presentation/pages/admin_seed_screen.dart"
)

$importLine = "import 'package:autodoc/core/utils/responsive.dart';"

foreach ($f in $files) {
  $content = Get-Content $f -Raw
  if (-not $content.Contains("responsive.dart")) {
    # Find the last import line and add after it
    $lines = $content -split "`r?`n"
    $lastImportIdx = -1
    for ($i = 0; $i -lt $lines.Length; $i++) {
      if ($lines[$i] -match "^import ") {
        $lastImportIdx = $i
      }
    }
    if ($lastImportIdx -ge 0) {
      $newLines = @()
      for ($i = 0; $i -lt $lines.Length; $i++) {
        $newLines += $lines[$i]
        if ($i -eq $lastImportIdx) {
          $newLines += $importLine
        }
      }
      $newContent = $newLines -join "`r`n"
      Set-Content -Path $f -Value $newContent -NoNewline
      Write-Host "Added import to: $f"
    }
  } else {
    Write-Host "Already has import: $f"
  }
}
