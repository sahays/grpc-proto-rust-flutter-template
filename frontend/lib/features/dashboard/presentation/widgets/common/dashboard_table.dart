import 'dart:ui';

import 'package:flutter/material.dart';

class DashboardTable extends StatelessWidget {
  final List<String> headers;
  final List<List<Widget>> rows;
  final List<double>? columnWidths;

  const DashboardTable({
    super.key,
    required this.headers,
    required this.rows,
    this.columnWidths,
  }) : assert(columnWidths == null || columnWidths.length == headers.length,
            'columnWidths length must match headers length');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E293B).withOpacity(0.7)
                : Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.05),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.05),
                    ),
                  ),
                ),
                child: Row(
                  children: List.generate(headers.length, (index) {
                    return Expanded(
                      flex: columnWidths != null ? (columnWidths![index] * 10).toInt() : 1,
                      child: Text(
                        headers[index],
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                      ),
                    );
                  }),
                ),
              ),
              // Rows
              if (rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'No data available',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: rows.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.05),
                  ),
                  itemBuilder: (context, rowIndex) {
                    final row = rows[rowIndex];
                    return HoverableTableRow(
                      children: List.generate(row.length, (colIndex) {
                         return Expanded(
                          flex: columnWidths != null ? (columnWidths![colIndex] * 10).toInt() : 1,
                          child: row[colIndex],
                        );
                      }),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class HoverableTableRow extends StatefulWidget {
  final List<Widget> children;

  const HoverableTableRow({super.key, required this.children});

  @override
  State<HoverableTableRow> createState() => _HoverableTableRowState();
}

class _HoverableTableRowState extends State<HoverableTableRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        color: _isHovered
            ? (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: widget.children,
        ),
      ),
    );
  }
}
