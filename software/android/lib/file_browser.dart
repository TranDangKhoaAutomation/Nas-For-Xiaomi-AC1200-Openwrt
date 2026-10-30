import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'media_view.dart';
import 'smb_service.dart';

class NasFileBrowser extends StatefulWidget {
  const NasFileBrowser({
    super.key,
    required this.service,
    required this.shares,
    required this.share,
    required this.path,
    required this.entries,
    required this.busy,
    required this.onShare,
    required this.onOpen,
    required this.onDownload,
    required this.onRename,
    required this.onRemove,
    required this.onUp,
    required this.onNewFolder,
    required this.onUpload,
    required this.onRefresh,
    this.available,
    this.total,
  });
  final NasService service;
  final List<String> shares;
  final String share, path;
  final List<NasEntry> entries;
  final bool busy;
  final num? available, total;
  final void Function(String) onShare;
  final void Function(NasEntry) onOpen, onDownload, onRename, onRemove;
  final VoidCallback onUp, onNewFolder, onUpload;
  final Future<void> Function() onRefresh;
  @override
  State<NasFileBrowser> createState() => _NasFileBrowserState();
}

class _NasFileBrowserState extends State<NasFileBrowser> {
  bool grid = true;
  static const storage = FlutterSecureStorage();
  @override
  void initState() {
    super.initState();
    storage
        .read(key: 'file-grid')
        .then((value) {
          if (mounted) setState(() => grid = value != 'false');
        })
        .catchError((_) {});
  }

  void changeView(bool next) {
    setState(() => grid = next);
    storage.write(key: 'file-grid', value: '$next').catchError((_) {});
  }

  String child(String name) =>
      widget.path.isEmpty ? name : '${widget.path}/$name';
  Widget preview(NasEntry entry, {bool large = false}) => NasPreview(
    service: widget.service,
    entry: entry,
    path: child(entry.name),
    large: large,
  );
  Widget menu(NasEntry entry) => PopupMenuButton<String>(
    enabled: !widget.busy,
    tooltip: 'Thao tác',
    onSelected: (value) {
      if (value == 'open') widget.onOpen(entry);
      if (value == 'download') widget.onDownload(entry);
      if (value == 'rename') widget.onRename(entry);
      if (value == 'delete') widget.onRemove(entry);
    },
    itemBuilder: (_) => [
      if (!entry.isDirectory && (isImage(entry.name) || isVideo(entry.name)))
        const PopupMenuItem(value: 'open', child: Text('Xem trực tuyến')),
      if (!entry.isDirectory)
        const PopupMenuItem(value: 'download', child: Text('Tải xuống')),
      const PopupMenuItem(value: 'rename', child: Text('Đổi tên')),
      const PopupMenuItem(value: 'delete', child: Text('Xóa')),
    ],
  );
  Widget item(NasEntry entry) {
    if (!grid) {
      return ListTile(
        leading: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            entry.isDirectory
                ? Icons.folder
                : isVideo(entry.name)
                ? Icons.movie_outlined
                : isImage(entry.name)
                ? Icons.image_outlined
                : Icons.insert_drive_file_outlined,
            color: entry.isDirectory
                ? const Color(0xffdfa439)
                : const Color(0xff07898d),
          ),
        ),
        title: Text(entry.name, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(entry.isDirectory ? 'Thư mục' : formatBytes(entry.size)),
        onTap: widget.busy ? null : () => widget.onOpen(entry),
        trailing: menu(entry),
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.busy ? null : () => widget.onOpen(entry),
        child: Column(
          children: [
            Expanded(
              child: Container(
                color: const Color(0xffe9eff2),
                width: double.infinity,
                child: preview(entry, large: true),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 0, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          entry.isDirectory
                              ? 'Thư mục'
                              : formatBytes(entry.size),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.blueGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 32, child: menu(entry)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButton<String>(
              isExpanded: true,
              value: widget.shares.contains(widget.share) ? widget.share : null,
              items: widget.shares
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: widget.busy ? null : (s) => widget.onShare(s!),
            ),
            if (widget.available != null)
              Text(
                '${formatBytes(widget.available)} trống / ${formatBytes(widget.total)}',
                style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
              ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Thư mục cha',
              onPressed: widget.path.isEmpty || widget.busy
                  ? null
                  : widget.onUp,
              icon: const Icon(Icons.arrow_upward),
            ),
            Expanded(
              child: Text(
                widget.path.isEmpty ? '/' : widget.path,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              tooltip: 'Tạo thư mục',
              onPressed: widget.busy ? null : widget.onNewFolder,
              icon: const Icon(Icons.create_new_folder_outlined),
            ),
            IconButton(
              tooltip: 'Tải lên',
              onPressed: widget.busy ? null : widget.onUpload,
              icon: const Icon(Icons.upload_outlined),
            ),
            IconButton(
              tooltip: 'Làm mới',
              onPressed: widget.busy ? null : () => widget.onRefresh(),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            Text(
              '${widget.entries.length} mục',
              style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
            ),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Lưới')),
                ButtonSegment(value: false, label: Text('Danh sách')),
              ],
              selected: {grid},
              showSelectedIcon: true,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              onSelectionChanged: (value) => changeView(value.first),
            ),
          ],
        ),
      ),
      Expanded(
        child: widget.entries.isEmpty
            ? const Center(child: Text('Thư mục trống'))
            : RefreshIndicator(
                onRefresh: widget.onRefresh,
                child: grid
                    ? GridView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 190,
                              childAspectRatio: .86,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                        itemCount: widget.entries.length,
                        itemBuilder: (_, i) => item(widget.entries[i]),
                      )
                    : ListView.separated(
                        itemCount: widget.entries.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, indent: 68),
                        itemBuilder: (_, i) => item(widget.entries[i]),
                      ),
              ),
      ),
    ],
  );
}
