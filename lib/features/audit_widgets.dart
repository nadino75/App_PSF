import 'package:flutter/material.dart';
import '../core/models.dart';
import '../core/audit.dart';
import '../data/repository.dart';

class RoleIndicator extends StatelessWidget {
  final Account account;
  final bool isOwner;

  const RoleIndicator({
    required this.account,
    required this.isOwner,
  });

  @override
  Widget build(BuildContext context) {
    final role = account.admin
      ? 'Administrador'
      : isOwner
        ? 'Dueño de negocio'
        : 'Usuario';

    final color = account.admin
      ? Colors.red
      : isOwner
        ? Colors.orange
        : Colors.blue;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(account.admin ? Icons.security : isOwner ? Icons.store : Icons.person, color: color),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tu rol:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text(role, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AuditLogTile extends StatelessWidget {
  final AuditLog log;

  const AuditLogTile(this.log);

  @override
  Widget build(BuildContext context) {
    final actionName = log.action.toString().split('.').last;

    return ListTile(
      leading: _resultIcon(log.result),
      title: Text(actionName, style: const TextStyle(fontSize: 14)),
      subtitle: Text(
        '${log.targetType ?? 'Acción'} • ${log.timestamp.toString().split('.')[0]}',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: log.result == 'success'
        ? const Icon(Icons.check_circle, color: Colors.green, size: 18)
        : log.result == 'denied'
          ? const Icon(Icons.block, color: Colors.red, size: 18)
          : const Icon(Icons.info, color: Colors.orange, size: 18),
    );
  }

  Icon _resultIcon(String? result) {
    switch (result) {
      case 'success':
        return const Icon(Icons.check_circle, color: Colors.green);
      case 'denied':
        return const Icon(Icons.block, color: Colors.red);
      case 'error':
        return const Icon(Icons.error, color: Colors.orange);
      default:
        return const Icon(Icons.info);
    }
  }
}

class MyActivitySection extends StatelessWidget {
  final AppRepository repository;

  const MyActivitySection({required this.repository});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Mi actividad', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        FutureBuilder<List<AuditLog>>(
          future: repository.fetchMyAuditLogs(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final logs = snapshot.data ?? [];
            if (logs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Sin actividad registrada', style: TextStyle(color: Colors.grey)),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: logs.length,
              itemBuilder: (context, index) => AuditLogTile(logs[index]),
            );
          },
        ),
      ],
    );
  }
}

class GlobalAuditSection extends StatelessWidget {
  final AppRepository repository;

  const GlobalAuditSection({required this.repository});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Auditoría global', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        FutureBuilder<List<AuditLog>>(
          future: repository.fetchAuditLogs(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final logs = snapshot.data ?? [];
            if (logs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Sin registros', style: TextStyle(color: Colors.grey)),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: logs.length,
              itemBuilder: (context, index) => AuditLogTile(logs[index]),
            );
          },
        ),
      ],
    );
  }
}
