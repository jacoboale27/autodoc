import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/admin_dashboard_provider.dart';
import '../widgets/admin_sidebar.dart';
import '../widgets/metric_card.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminDashboardProvider>().fetchMetrics();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminDashboardProvider>();
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Administrador'),
        centerTitle: true,
      ),
      drawer: const AdminSidebar(),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.error != null
              ? Center(child: Text('Error: ${provider.error}'))
              : RefreshIndicator(
                  onRefresh: provider.fetchMetrics,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '¡Bienvenido, ${authProvider.userData?.nombreCompleto ?? 'Admin'}!',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            Text(
                              'Aquí tienes el resumen actual de la plataforma.',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'Métricas Globales',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        GridView.count(
                          crossAxisCount: MediaQuery.of(context).size.width > 900 ? 3 : (MediaQuery.of(context).size.width > 600 ? 2 : 1),
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 20,
                          shrinkWrap: true,
                          childAspectRatio: 1.6,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            MetricCard(
                              title: 'Usuarios',
                              value: '${provider.metrics['usuarios']}',
                              icon: Icons.people,
                              color: Colors.blue,
                            ),
                            MetricCard(
                              title: 'Talleres',
                              value: '${provider.metrics['talleres']}',
                              icon: Icons.build,
                              color: Colors.orange,
                            ),
                            MetricCard(
                              title: 'Vehículos',
                              value: '${provider.metrics['vehiculos']}',
                              icon: Icons.directions_car,
                              color: Colors.purple,
                            ),
                            MetricCard(
                              title: 'Servicios',
                              value: '${provider.metrics['servicios']}',
                              icon: Icons.miscellaneous_services,
                              color: Colors.green,
                            ),
                            MetricCard(
                              title: 'Alertas',
                              value: '${provider.metrics['alertas']}',
                              icon: Icons.warning,
                              color: Colors.red,
                            ),
                            MetricCard(
                              title: 'Reseñas',
                              value: '${provider.metrics['resenias']}',
                              icon: Icons.rate_review,
                              color: Colors.teal,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
