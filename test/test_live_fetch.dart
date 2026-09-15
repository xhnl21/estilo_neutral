// ignore_for_file: avoid_print
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:estilo_neutral/shared/google_sheets/sheets_data_service.dart';

void main() {
  test('Live fetch from Google Sheets with user gid URL', () async {
    HttpOverrides.global = null;
    const userUrl = 'https://docs.google.com/spreadsheets/d/1zJWnxXk3QSG-keyOHMEOrfY72cmtLUdv/edit?gid=1553944720#gid=1553944720';
    final ds = SheetsDataService(spreadsheetId: userUrl);
    expect(ds.spreadsheetId, '1zJWnxXk3QSG-keyOHMEOrfY72cmtLUdv');
    print('Spreadsheet ID extraído: ${ds.spreadsheetId}');
    await ds.fetchAllSheets();
    print('Fetch completed.');
    print('Error message: ${ds.errorMessage}');
    print('Clientes: ${ds.clientes.length}');
    print('Primer cliente: ${ds.clientes.first.nombre} (${ds.clientes.first.id})');
    expect(ds.clientes.first.nombre, 'Neida Alexandra');
    expect(ds.productos.first.precioUsd, 20.0);
    expect(ds.ventas.first.montoBs, 9480.0);
  });
}
