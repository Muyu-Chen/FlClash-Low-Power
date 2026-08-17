import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

import 'item.dart';

class ConnectionsView extends ConsumerStatefulWidget {
  const ConnectionsView({super.key});

  @override
  ConsumerState<ConnectionsView> createState() => _ConnectionsViewState();
}

class _ConnectionsViewState extends ConsumerState<ConnectionsView> {
  static const _sortRefreshInterval = Duration(seconds: 5);

  final _connectionsStateNotifier = ValueNotifier<TrackerInfosState>(
    const TrackerInfosState(),
  );
  final ScrollController _scrollController = ScrollController();
  ConnectionSortType _sortType = ConnectionSortType.none;
  DateTime? _lastUpdateTime;
  DateTime? _lastSortTime;
  List<String> _orderedConnectionIds = const [];

  Timer? timer;

  String _getSortLabel(BuildContext context, ConnectionSortType sortType) {
    final appLocalizations = context.appLocalizations;
    return switch (sortType) {
      ConnectionSortType.none => appLocalizations.defaultText,
      ConnectionSortType.downloadDesc => '${appLocalizations.download} ↓',
      ConnectionSortType.downloadAsc => '${appLocalizations.download} ↑',
      ConnectionSortType.uploadDesc => '${appLocalizations.upload} ↓',
      ConnectionSortType.uploadAsc => '${appLocalizations.upload} ↑',
      ConnectionSortType.processAsc => '${appLocalizations.process} ↑',
      ConnectionSortType.processDesc => '${appLocalizations.process} ↓',
    };
  }

  List<PopupMenuEntry<ConnectionSortType>> _buildSortItems(
    BuildContext context,
  ) {
    const groups = [
      [ConnectionSortType.none],
      [ConnectionSortType.downloadDesc, ConnectionSortType.downloadAsc],
      [ConnectionSortType.uploadDesc, ConnectionSortType.uploadAsc],
      [ConnectionSortType.processAsc, ConnectionSortType.processDesc],
    ];
    return [
      for (var groupIndex = 0; groupIndex < groups.length; groupIndex++) ...[
        if (groupIndex > 0) const PopupMenuDivider(),
        for (final item in groups[groupIndex])
          CheckedPopupMenuItem<ConnectionSortType>(
            value: item,
            checked: item == _sortType,
            child: Text(_getSortLabel(context, item)),
          ),
      ],
    ];
  }

  List<Widget> _buildActions(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return [
      PopupMenuButton<ConnectionSortType>(
        tooltip:
            '${appLocalizations.sort}: ${_getSortLabel(context, _sortType)}',
        icon: const Icon(Icons.sort),
        onSelected: (sortType) {
          setState(() {
            _sortType = sortType;
            _updateConnectionOrder(
              _connectionsStateNotifier.value.trackerInfos,
              force: true,
            );
          });
        },
        itemBuilder: _buildSortItems,
      ),
      IconButton(
        onPressed: () async {
          coreController.closeConnections();
          await _updateConnections();
        },
        icon: const Icon(Icons.delete_sweep_outlined),
      ),
    ];
  }

  void _updateConnectionOrder(
    List<TrackerInfo> connections, {
    bool force = false,
  }) {
    final ids = connections.map((item) => item.id).toList();
    if (_sortType == ConnectionSortType.none) {
      _orderedConnectionIds = ids;
      _lastSortTime = null;
      return;
    }
    final now = DateTime.now();
    final previousIds = _orderedConnectionIds.toSet();
    final membershipChanged =
        previousIds.length != ids.length ||
        ids.any((id) => !previousIds.contains(id));
    final shouldRefresh =
        force ||
        membershipChanged ||
        _lastSortTime == null ||
        now.difference(_lastSortTime!) >= _sortRefreshInterval;
    if (!shouldRefresh) {
      return;
    }
    _orderedConnectionIds = connections
        .sortedBy(_sortType)
        .map((item) => item.id)
        .toList();
    _lastSortTime = now;
  }

  void _onSearch(String value) {
    _connectionsStateNotifier.value = _connectionsStateNotifier.value.copyWith(
      query: value,
    );
  }

  void _onKeywordsUpdate(List<String> keywords) {
    _connectionsStateNotifier.value = _connectionsStateNotifier.value.copyWith(
      keywords: keywords,
    );
  }

  Future<void> _updateConnectionsTask() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        await _updateConnections();
        timer = Timer(const Duration(seconds: 1), () async {
          _updateConnectionsTask();
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _updateConnectionsTask();
  }

  Future<void> _updateConnections() async {
    try {
      final trackerInfos = await coreController.getConnections();
      if (!mounted) {
        return;
      }
      final updateTime = DateTime.now();
      final previousUpdateTime = _lastUpdateTime;
      final previousById = {
        for (final item in _connectionsStateNotifier.value.trackerInfos)
          item.id: item,
      };
      final elapsed = previousUpdateTime == null
          ? Duration.zero
          : updateTime.difference(previousUpdateTime);
      final trackerInfosWithSpeed = trackerInfos.map((item) {
        return item.withSpeedFrom(previousById[item.id], elapsed);
      }).toList();
      _lastUpdateTime = updateTime;
      _updateConnectionOrder(trackerInfosWithSpeed);
      _connectionsStateNotifier.value = _connectionsStateNotifier.value
          .copyWith(trackerInfos: trackerInfosWithSpeed);
    } catch (error) {
      commonPrint.log(
        'updateConnections error: $error',
        logLevel: coreFailureLogLevel(error),
      );
    }
  }

  Future<void> _handleBlockConnection(String id) async {
    await coreController.closeConnection(id);
    await _updateConnections();
  }

  @override
  void dispose() {
    timer?.cancel();
    _connectionsStateNotifier.dispose();
    _scrollController.dispose();
    timer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonScaffold(
      title: appLocalizations.connections,
      onKeywordsUpdate: _onKeywordsUpdate,
      searchState: AppBarSearchState(onSearch: _onSearch),
      actions: _buildActions(context),
      body: ValueListenableBuilder<TrackerInfosState>(
        valueListenable: _connectionsStateNotifier,
        builder: (context, state, _) {
          final connections = state.list.orderedByIds(_orderedConnectionIds);
          if (connections.isEmpty) {
            return NullStatus(
              label: appLocalizations.nullTip(appLocalizations.connections),
              illustration: const ConnectionEmptyIllustration(),
            );
          }
          final items = connections
              .map<Widget>(
                (trackerInfo) => TrackerInfoItem(
                  key: Key(trackerInfo.id),
                  trackerInfo: trackerInfo,
                  onClickKeyword: (value) {
                    context.commonScaffoldState?.addKeyword(value);
                  },
                  trailing: IconButton(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(minimumSize: Size.zero),
                    icon: const Icon(Icons.block),
                    onPressed: () {
                      _handleBlockConnection(trackerInfo.id);
                    },
                  ),
                  detailTitle: appLocalizations.details(
                    appLocalizations.connection,
                  ),
                  compact: true,
                ),
              )
              .separated(const Divider(height: 0))
              .toList();
          return SuperListView.builder(
            controller: _scrollController,
            itemBuilder: (context, index) {
              return items[index];
            },
            itemCount: connections.length,
          );
        },
      ),
    );
  }
}
