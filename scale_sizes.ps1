$files = @(
  "lib/features/dashboard/presentation/pages/task_config_screen.dart",
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
  
  # Replace fontSize: <number> with Responsive.fontSize(context, <number>)
  # But only for GoogleFonts/TextStyle declarations, not for already-responsive ones
  $content = $content -replace 'fontSize: (\d+\.?\d*)', 'fontSize: Responsive.fontSize(context, $1)'
  
  # Fix double-wrapped ones (in case the file already had some)
  $content = $content -replace 'Responsive\.fontSize\(context, Responsive\.fontSize\(context, (\d+\.?\d*)\)\)', 'Responsive.fontSize(context, $1)'
  
  # Replace size: <number> in Icon widgets - careful with pattern
  # Icon(..., size: 24) -> Icon(..., size: Responsive.iconSize(context, 24))
  $content = $content -replace '(Icon\([^)]*?)size: (\d+\.?\d*)', '$1size: Responsive.iconSize(context, $2)'
  
  # Fix double-wrapped icon sizes
  $content = $content -replace 'Responsive\.iconSize\(context, Responsive\.iconSize\(context, (\d+\.?\d*)\)\)', 'Responsive.iconSize(context, $1)'
  
  Set-Content -Path $f -Value $content -NoNewline
  Write-Host "Processed: $f"
}
