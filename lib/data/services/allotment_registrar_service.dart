import 'package:get/get.dart';

import '../models/allotment_check_result.dart';
import '../models/ipo.dart';
import 'kfin_allotment_service.dart';
import 'mufg_allotment_service.dart';

class AllotmentRegistrarService extends GetxService {
  AllotmentRegistrarService({
    KfinAllotmentService? kfin,
    MufgAllotmentService? mufg,
  })  : _kfin = kfin ?? KfinAllotmentService(),
        _mufg = mufg ?? MufgAllotmentService();

  final KfinAllotmentService _kfin;
  final MufgAllotmentService _mufg;

  bool supportsRegistrar(Ipo ipo) {
    return _kfin.supportsRegistrar(ipo) ||
        _mufg.supportsRegistrar(ipo) ||
        isBigshare(ipo);
  }

  /// Bigshare is supported as a manual in-app website flow, not through its API.
  bool isBigshare(Ipo ipo) {
    final registrar = '${ipo.registrarCode ?? ''} ${ipo.registrarName ?? ''}'
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), ' ')
        .trim();
    final compact = registrar.replaceAll(' ', '');

    return registrar.contains('BIGSHARE') ||
        compact.contains('BIGSHAREONLINE') ||
        compact.contains('BIGSHARESERVICES');
  }

  Future<AllotmentCheckResult> checkAllotment({
    required Ipo ipo,
    required String pan,
    bool skipAllotmentDateGuard = false,
  }) async {
    try {
      if (_kfin.supportsRegistrar(ipo)) {
        return await _kfin.checkAllotment(
          ipo: ipo,
          pan: pan,
          skipAllotmentDateGuard: skipAllotmentDateGuard,
        );
      }

      if (_mufg.supportsRegistrar(ipo)) {
        return await _mufg.checkAllotment(
          ipo: ipo,
          pan: pan,
          skipAllotmentDateGuard: skipAllotmentDateGuard,
        );
      }

      if (isBigshare(ipo)) {
        return AllotmentCheckResult(
          status: AllotmentApiStatus.humanRequired,
          registrar: 'BIGSHARE',
          ipoName: ipo.name,
          message: 'Bigshare allotment is checked manually on the Bigshare website.',
        );
      }
    } on KfinAllotmentException catch (error) {
      throw AllotmentRegistrarException(
        error.message,
        statusCode: error.statusCode,
      );
    } on MufgAllotmentException catch (error) {
      throw AllotmentRegistrarException(
        error.message,
        statusCode: error.statusCode,
      );
    }

    return AllotmentCheckResult(
      status: AllotmentApiStatus.unsupportedRegistrar,
      registrar: ipo.registrarCode ?? ipo.registrarName ?? '',
      ipoName: ipo.name,
      message: 'This registrar checker is not available yet.',
    );
  }
}

class AllotmentRegistrarException implements Exception {
  const AllotmentRegistrarException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
