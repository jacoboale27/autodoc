import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/vehicle_model.dart';
import '../models/service_record_model.dart';

class PdfGenerator {
  static Future<void> generateServiceHistoryPdf(VehicleModel vehicle, List<ServiceRecordModel> services) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildHeader(vehicle),
            pw.SizedBox(height: 20),
            _buildSummary(services),
            pw.SizedBox(height: 20),
            _buildServiceTable(services),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'historial_servicios_${vehicle.placa}.pdf',
    );
  }

  static pw.Widget _buildHeader(VehicleModel vehicle) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Historial de Servicios', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.Text('Vehículo: ${vehicle.marca} ${vehicle.modelo} (${vehicle.anio})'),
        pw.Text('Placa: ${vehicle.placa}'),
        pw.Text('Fecha de Reporte: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}'),
        pw.Divider(),
      ],
    );
  }

  static pw.Widget _buildSummary(List<ServiceRecordModel> services) {
    final double totalGasto = services.fold(0, (sum, item) => sum + (item.costo ?? 0.0));
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('Total de Servicios: ${services.length}'),
        pw.Text('Gasto Total: \$${totalGasto.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  static pw.Widget _buildServiceTable(List<ServiceRecordModel> services) {
    return pw.TableHelper.fromTextArray(
      headers: ['Fecha', 'Servicio', 'Taller', 'Costo'],
      data: services.map((s) {
        return [
          DateFormat('dd/MM/yyyy').format(s.fecha),
          s.tipoServicio,
          s.idTaller, // Idealmente el nombre, pero por ahora el ID
          '\$${(s.costo ?? 0.0).toStringAsFixed(2)}'
        ];
      }).toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellHeight: 30,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.centerRight,
      },
    );
  }
}
