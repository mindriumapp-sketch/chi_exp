import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:gad_app_team/data/notification_provider.dart';
import 'package:gad_app_team/common/constants.dart';

/// MapPicker: 위치 선택 및 편집 위젯
/// - initial이 주어질 경우 편집 모드로 동작
/// - initial 위치를 중심으로 지도 이동, 현위치 이동은 방지
/// - 현위치, 저장된 위치, 선택된 위치를 모두 표시
class MapPicker extends StatefulWidget {
  /// 편집 모드로 들어올 때 기존 선택 위치
  final LatLng? initial;

  const MapPicker({super.key, this.initial});

  @override
  State<MapPicker> createState() => _MapPickerState();
}

class _MapPickerState extends State<MapPicker> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  List<Marker> _savedMarkers = [];
  LatLng? _picked;      // 사용자가 고른 위치 혹은 initial
  LatLng? _current;     // 현위치
  String? _addr;        // 역지오코딩 주소

  // ────────────── 사용자 정의 카테고리 ──────────────
  List<String> _customCategories = [];
  bool _customCategoryFinalized = false;

  Future<void> _loadCustomCategories() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('map_picker_config')
        .doc('custom_categories')
        .get();
    if (snap.exists) {
      final data = snap.data();
      final list = (data?['categories'] as List?)?.cast<String>() ?? [];
      setState(() => _customCategories = list);
    }
  }

  Future<void> _saveCustomCategory(String newCat) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _customCategories.insert(0, newCat);
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('map_picker_config')
        .doc('custom_categories')
        .set({'categories': _customCategories});
  }

  /// 커스텀 카테고리를 삭제하고 Firestore에도 즉시 반영
  Future<void> _removeCustomCategory(String cat) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _customCategories.remove(cat);
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('map_picker_config')
        .doc('custom_categories')
        .set({'categories': _customCategories});
  }

  // ────────────── 초기화 ──────────────
  @override
  void initState() {
    super.initState();

    // 편집 모드이면 initial 값을 _picked와 _addr로 세팅
    if (widget.initial != null) {
      _picked = widget.initial;
      _reverseGeocode(widget.initial!);
    }

    _determinePosition();    // 현위치만 가져오고, 지도 이동은 조건부
    _loadSavedLocations();   // 저장된 위치 마커 로드
  }

  /// Firestore에서 저장된 'location' 알림 위치 불러오기
  Future<void> _loadSavedLocations() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notification_settings')
        .where('method', isEqualTo: 'location')
        .get();

    final markers = <Marker>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final lat = (data['latitude'] as num?)?.toDouble();
      final lng = (data['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;

      markers.add(
        Marker(
          point: LatLng(lat, lng),
          width: 36,
          height: 36,
          child: const Icon(Icons.star, color: Colors.amber),
        ),
      );
    }
    if (mounted) setState(() => _savedMarkers = markers);
  }

  // ────────────── 현위치 가져오기 ──────────────
  Future<void> _determinePosition() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    final pos = await Geolocator.getCurrentPosition();
    if (!mounted) return;
    setState(() => _current = LatLng(pos.latitude, pos.longitude));

    // initial이 없을 때만 지도 이동
    if (widget.initial == null) {
      _mapController.move(_current!, 16);
    }
  }

  // ────────────── 텍스트 검색 ──────────────
  Future<void> _onSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    try {
      final res = await locationFromAddress(query);
      if (res.isNotEmpty && mounted) {
        final latlng = LatLng(res.first.latitude, res.first.longitude);
        setState(() {
          _picked = latlng;
          _addr   = query;
        });
        _mapController.move(latlng, 16);
      }
    } catch (_) {}
  }

  // ────────────── 역지오코딩 ──────────────
  Future<void> _reverseGeocode(LatLng point) async {
    try {
      final ps = await placemarkFromCoordinates(point.latitude, point.longitude);
      if (ps.isNotEmpty && mounted) {
        setState(() => _addr = ps.first.street ?? ps.first.locality);
      }
    } catch (_) {}
  }

  // ────────────── 설명 입력 ──────────────
  Future<String?> _askDescription() async {

    // Firestore에서 커스텀 카테고리 불러오기
    await _loadCustomCategories();
    if (!mounted) return null;
    setState(() => _customCategoryFinalized = false);
    final result = await showModalBottomSheet<String>(
      backgroundColor: Colors.grey.shade100,
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (ctx) {
        String? selectedCategory;
        // 커스텀 + 기본 카테고리
        List<String> categories = [
          ..._customCategories,
          '학교',
          '지하철',
          '쇼핑몰',
          '식당',
          '카페',
          '병원',
          '집',
          '직장',
          '+ 추가',
        ];
        // 로컬에서만 삭제표시
        return StatefulBuilder(
          builder: (ctx2, setLocal) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx2).viewInsets.bottom,
              left: AppSizes.padding,
              right: AppSizes.padding,
              top: AppSizes.padding,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('위치에 대한 설명을 선택하거나 추가해 주세요.',
                      style: TextStyle(fontSize: AppSizes.fontSize)),
                  const SizedBox(height: AppSizes.space),
                  Wrap(
                    spacing: 16,
                    children: categories.map((cat) {
                      final selected = selectedCategory == cat;
                      final isCustom = _customCategories.contains(cat);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Stack(
                          alignment: Alignment.centerRight,
                          children: [
                            ChoiceChip(
                              showCheckmark: false,
                              backgroundColor: Colors.white,
                              selectedColor: Colors.indigo,
                              label: Text(
                                cat,
                                style: TextStyle(
                                    color: selected ? Colors.white : Colors.black),
                              ),
                              labelPadding: EdgeInsets.only(
                                left: 8,
                                // X 아이콘이 들어가는 경우(커스텀 & 아직 확정 전)엔 오른쪽 여유 공간 확보
                                right: (isCustom && !_customCategoryFinalized) ? 16 : 8,
                              ),
                              selected: selected,
                              onSelected: (yes) async {
                                if (!yes) return;
                                // “+ 추가” → 사용자 입력 받기
                                if (cat == '+ 추가') {
                                  final newCat = await showDialog<String>(
                                    context: ctx2,
                                    builder: (dCtx) {
                                      final txtCtrl = TextEditingController();
                                      return AlertDialog(
                                        title: const Text('카테고리 추가'),
                                        content: TextField(
                                          controller: txtCtrl,
                                          autofocus: true,
                                          decoration: const InputDecoration(hintText: '예: 학원'),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(dCtx),
                                            child: const Text('취소'),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              final val = txtCtrl.text.trim();
                                              Navigator.pop(dCtx, val.isEmpty ? null : val);
                                            },
                                            child: const Text('추가'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                  if (newCat != null && newCat.isNotEmpty) {
                                    await _saveCustomCategory(newCat);
                                    if (!_customCategories.contains(newCat)) {
                                      _customCategories.insert(0,newCat);
                                    }
                                    setState(() {}); // Refresh outer widget state
                                    setLocal(() {
                                      categories = [
                                        ..._customCategories,
                                        '학교',
                                        '지하철',
                                        '쇼핑몰',
                                        '식당',
                                        '카페',
                                        '병원',
                                        '집',
                                        '직장',
                                        '+ 추가',
                                      ];
                                      selectedCategory = newCat;
                                    });
                                  }
                                } else {
                                  // 일반 카테고리 선택
                                  setLocal(() => selectedCategory = cat);
                                }
                              },
                            ),
                            // 삭제 버튼: 커스텀 카테고리, 확정 전만
                            if (!_customCategoryFinalized && isCustom)
                              Align(
                                alignment: Alignment.centerRight,
                                widthFactor: 1,  // 아이콘 영역만큼만 차지
                                child: InkWell(
                                  // Chip과 동일한 작고 컴팩트한 탭 영역
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () async {
                                    // 1) Firestore와 전역 목록(_customCategories)에서 제거
                                    await _removeCustomCategory(cat);
                                    // 2) 현재 모달의 로컬 목록 갱신
                                    setLocal(() {
                                      categories.remove(cat);
                                      if (selectedCategory == cat) {
                                        selectedCategory = null;
                                      }
                                    });
                                    // 3) 외부 상태도 새로고침
                                    if (mounted) setState(() {});
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 4),
                                    child: Icon(
                                      Icons.close,
                                      size: 18,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                ),
                              )
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSizes.space),
                  NavigationButtons(
                    leftLabel: '이전',
                    rightLabel: '완료',
                    onBack: () => Navigator.of(ctx2).pop(),
                    onNext: () {
                      Navigator.of(ctx2).pop('$selectedCategory');
                    },
                  ),
                  const SizedBox(height: AppSizes.space * 2),
                ],
              ),
            ),
          ),
        );
      },
    );
    return result;
  }

  // ────────────── 확정 버튼 ──────────────
  Future<void> _confirmSelection() async {
    final latlng = _picked ?? _current ?? const LatLng(37.5665, 126.9780);
    if (_addr == null) await _reverseGeocode(latlng);

    final descInput = await _askDescription();
    if (descInput == null) return;
    if (!mounted) return;

    // descInput format: "category|enter,exit"
    final parts = descInput.split('|');
    final category = parts.first;
    final timing = parts.length > 1 ? parts[1] : '';
    final notifyEnter = timing.contains('enter');
    final notifyExit = timing.contains('exit');

    // 설명(주소) 형식으로 저장
    final locString = (_addr != null && _addr!.isNotEmpty)
        ? '$category ($_addr)'
        : (_addr ?? category);

    final finalDesc = category.isNotEmpty ? category : (_addr ?? '선택한 위치');

    // DEBUG: description 전달됨 → $finalDesc
    debugPrint('DEBUG: description 전달됨 → $finalDesc');

    // 더 이상 카테고리 편집 불가
    setState(() => _customCategoryFinalized = true);

    Navigator.of(context).pop(
      NotificationSetting(
//        method: NotificationMethod.location,
        location: locString, // 학교(서울특별시…) 형태
        latitude: latlng.latitude,
        longitude: latlng.longitude,
        description: finalDesc,
        notifyEnter: notifyEnter,
        notifyExit: notifyExit,
      ),
    );
  }

  // ────────────── 줌 컨트롤 ──────────────
  void _zoomIn() => _mapController.move(_mapController.camera.center, (_mapController.camera.zoom + 0.5).clamp(13.0, 19.0));
  void _zoomOut() => _mapController.move(_mapController.camera.center, (_mapController.camera.zoom - 0.5).clamp(13.0, 19.0));

  // ────────────── 위젯 트리 ──────────────
  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: widget.initial ?? _current ?? const LatLng(37.5665, 126.9780),
            initialZoom: 16,
            onTap: (tapPos, latlng) async {
              setState(() {
                _picked = latlng;
              });
              await _reverseGeocode(latlng);
            },
          ),
          children: [
            TileLayer(
              minZoom: 13,
              maxZoom: 19,
              urlTemplate: 'https://api.vworld.kr/req/wmts/1.0.0/{key}/Base/{z}/{y}/{x}.png',
              additionalOptions: {'key': vworldApiKey},
            ),
            // 현위치 마커
            if (_current != null)
              MarkerLayer(markers: [
                Marker(
                  point: _current!,
                  width: 36,
                  height: 36,
                  child: const Icon(Icons.my_location, size: 30, color: Colors.deepOrange),
                ),
              ]),
            // 선택된 위치 마커
            if (_picked != null)
              MarkerLayer(markers: [
                Marker(
                  point: _picked!,
                  width: 36,
                  height: 36,
                  child: const Icon(Icons.location_pin, size: 40, color: Colors.indigo),
                ),
              ]),
            // 저장된 위치 마커
            if (_savedMarkers.isNotEmpty)
              MarkerLayer(markers: _savedMarkers),
          ],
        ),

        // 검색창
        Positioned(
          top: AppSizes.padding * 4,
          left: AppSizes.padding,
          right: AppSizes.padding,
          child: Material(
            elevation: 1,
            borderRadius: BorderRadius.circular(8),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: '주소 검색',
                prefixIcon: Icon(Icons.search),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _onSearch(),
            ),
          ),
        ),

        // 취소/확인 버튼
        Positioned(
          bottom: AppSizes.padding * 2,
          left: 16,
          right: 16,
          child: NavigationButtons(
            onBack: () => Navigator.pop(context),
            onNext: _confirmSelection,
            leftLabel: '닫기',
            rightLabel: '확인',
          ),
        ),

        // 줌 버튼
        Positioned(
          bottom: AppSizes.padding * 8,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton(
                heroTag: 'zoomIn',
                backgroundColor: Colors.white,
                onPressed: _zoomIn,
                child: const Icon(Icons.add, color: Colors.black),
              ),
              const SizedBox(height: AppSizes.space / 2),
              FloatingActionButton(
                heroTag: 'zoomOut',
                backgroundColor: Colors.white,
                onPressed: _zoomOut,
                child: const Icon(Icons.remove, color: Colors.black),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}