$errorFiles = @(
  "lib/features/admin/presentation/pages/admin_dashboard_screen.dart",
  "lib/features/admin/presentation/pages/admin_resenias_screen.dart",
  "lib/features/admin/presentation/pages/admin_usuarios_screen.dart",
  "lib/features/mechanic/presentation/pages/initiate_service_screen.dart",
  "lib/features/mechanic/presentation/pages/mechanic_dashboard_screen.dart",
  "lib/features/mechanic/presentation/pages/vehicle_search_screen.dart",
  "lib/features/profile/presentation/pages/profile_setup_screen.dart",
  "lib/features/profile/presentation/pages/user_profile_screen.dart"
)

foreach ($f in $errorFiles) {
  $content = Get-Content $f -Raw
  
  $content = $content -replace 'const TextStyle\(', 'TextStyle('
  $content = $content -replace 'const Text\(', 'Text('
  
  Set-Content -Path $f -Value $content -NoNewline
}
