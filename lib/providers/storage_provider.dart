import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';

/// 全局存储服务 Provider（唯一来源，其他 provider 引用此处）
final storageProvider = Provider<StorageService>((ref) => StorageService());
