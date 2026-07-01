$files = @(
  "lib/features/dashboard/presentation/pages/task_config_screen.dart",
  "lib/features/dashboard/presentation/pages/task_complete_screen.dart",
  "lib/features/dashboard/presentation/pages/workshop_directory_screen.dart",
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

foreach ($f in $files) {
  $content = Get-Content $f -Raw
  
  # Replace "const EdgeInsets.all(<N>)" with "EdgeInsets.all(Responsive.padding(context, <N>))"
  $content = $content -replace 'const EdgeInsets\.all\((\d+\.?\d*)\)', 'EdgeInsets.all(Responsive.padding(context, $1))'
  
  # Replace "const EdgeInsets.symmetric(horizontal: <N>)" with non-const version
  $content = $content -replace 'const EdgeInsets\.symmetric\(horizontal: (\d+\.?\d*)\)', 'EdgeInsets.symmetric(horizontal: Responsive.padding(context, $1))'
  
  # Replace "const EdgeInsets.symmetric(horizontal: <N>, vertical: <N>)"
  $content = $content -replace 'const EdgeInsets\.symmetric\(horizontal: (\d+\.?\d*), vertical: (\d+\.?\d*)\)', 'EdgeInsets.symmetric(horizontal: Responsive.padding(context, $1), vertical: Responsive.padding(context, $2))'
  
  # Replace "const EdgeInsets.symmetric(vertical: <N>, horizontal: <N>)"
  $content = $content -replace 'const EdgeInsets\.symmetric\(vertical: (\d+\.?\d*), horizontal: (\d+\.?\d*)\)', 'EdgeInsets.symmetric(vertical: Responsive.padding(context, $1), horizontal: Responsive.padding(context, $2))'
  
  # Fix double-wraps
  $content = $content -replace 'Responsive\.padding\(context, Responsive\.padding\(context, (\d+\.?\d*)\)\)', 'Responsive.padding(context, $1)'
  
  Set-Content -Path $f -Value $content -NoNewline
  Write-Host "Processed paddings: $f"
}
