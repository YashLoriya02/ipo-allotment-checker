import '../models/ipo.dart';

abstract class IpoRepository {
  Future<List<Ipo>> getIpos();
  Future<Ipo?> getById(String id);
}
