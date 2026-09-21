import 'package:flutter/material.dart';

import '../app/app.dart';
import '../data/version_history.dart';

class VersionHistoryScreen extends StatelessWidget {
  const VersionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '版本历史',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          itemCount: ctdpVersionHistory.length,
          itemBuilder: (context, index) {
            final record = ctdpVersionHistory[index];

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 版本号与发布日期
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          record.version,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: CtdpColors.primary,
                          ),
                        ),
                        Text(
                          record.releaseDate,
                          style: const TextStyle(
                            fontSize: 12,
                            color: CtdpColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20, thickness: 0.8),
                    // 更新要点列表
                    ...record.changes.map((change) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 6, right: 8),
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: CtdpColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                change,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                  color: CtdpColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}