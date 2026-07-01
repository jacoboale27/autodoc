# Fix const_eval_method_invocation errors
# These happen when Responsive.xxx() is used inside a const constructor
# The fix is to remove the 'const' keyword from those constructors

$errorFiles = @(
  "lib/features/admin/presentation/pages/admin_dashboard_screen.dart",
  "lib/features/admin/presentation/pages/admin_resenias_screen.dart",
  "lib/features/admin/presentation/pages/admin_seed_screen.dart",
  "lib/features/admin/presentation/pages/admin_usuarios_screen.dart",
  "lib/features/dashboard/presentation/pages/workshop_directory_screen.dart",
  "lib/features/mechanic/presentation/pages/initiate_service_screen.dart",
  "lib/features/mechanic/presentation/pages/mechanic_dashboard_screen.dart",
  "lib/features/mechanic/presentation/pages/vehicle_search_screen.dart",
  "lib/features/profile/presentation/pages/profile_setup_screen.dart",
  "lib/features/profile/presentation/pages/user_profile_screen.dart"
)

foreach ($f in $errorFiles) {
  $content = Get-Content $f -Raw
  
  # Remove 'const' before Icon(...Responsive...) 
  $content = $content -replace 'const Icon\(([^)]*Responsive)', 'Icon($1'
  
  # Remove 'const' before EdgeInsets that contain Responsive
  # Already handled by our regex (we replaced 'const EdgeInsets' with 'EdgeInsets')
  # But check for any remaining const EdgeInsets with Responsive inside
  $content = $content -replace 'const EdgeInsets\.all\(Responsive', 'EdgeInsets.all(Responsive'
  $content = $content -replace 'const EdgeInsets\.symmetric\(([^)]*Responsive)', 'EdgeInsets.symmetric($1'
  $content = $content -replace 'const EdgeInsets\.fromLTRB\(([^)]*Responsive)', 'EdgeInsets.fromLTRB($1'
  $content = $content -replace 'const EdgeInsets\.only\(([^)]*Responsive)', 'EdgeInsets.only($1'
  
  # Remove 'const' before SizedBox that might contain Responsive
  $content = $content -replace 'const SizedBox\(([^)]*Responsive)', 'SizedBox($1'
  
  # Remove 'const' before Padding that contains Responsive
  $content = $content -replace 'const Padding\(([^)]*Responsive)', 'Padding($1'
  
  Set-Content -Path $f -Value $content -NoNewline
  Write-Host "Fixed const issues in: $f"
}
