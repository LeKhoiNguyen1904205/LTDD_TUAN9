import 'package:flutter/material.dart';
import 'package:sms_advanced/sms_advanced.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const SmsAnalyzerApp());
}

class SmsAnalyzerApp extends StatelessWidget {
  const SmsAnalyzerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SMS Analyzer',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const SmsAnalyzerHome(),
    );
  }
}

class SmsAnalyzerHome extends StatefulWidget {
  const SmsAnalyzerHome({super.key});

  @override
  State<SmsAnalyzerHome> createState() => _SmsAnalyzerHomeState();
}

class _SmsAnalyzerHomeState extends State<SmsAnalyzerHome> {
  List<SmsMessage> _allMessages = [];
  List<SmsMessage> _filteredMessages = [];
  bool _isLoading = true;
  String _selectedFilter = 'all';
  String _selectedPhone = '';
  Set<String> _phoneNumbers = {};

  @override
  void initState() {
    super.initState();
    _checkPermissionAndLoad();
  }

  Future<void> _checkPermissionAndLoad() async {
    final status = await Permission.sms.status;
    if (status.isGranted) {
      await _loadMessages();
    } else {
      final result = await Permission.sms.request();
      if (result.isGranted) {
        await _loadMessages();
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cần cấp quyền SMS để phân tích tin nhắn')),
        );
      }
    }
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      final SmsQuery query = SmsQuery();
      final List<SmsMessage> messages = await query.getAllSms;
      setState(() {
        _allMessages = messages.reversed.toList();
        _filteredMessages = messages.reversed.toList();
        _phoneNumbers = messages.map((m) => m.address ?? 'Không rõ').toSet();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi đọc tin nhắn: $e\nHãy kiểm tra quyền trong Settings')),
      );
    }
  }

  void _filterMessages() {
    setState(() {
      if (_selectedFilter == 'all') {
        _filteredMessages = _allMessages;
      } else if (_selectedFilter == 'phone') {
        _filteredMessages = _allMessages.where((m) => m.address == _selectedPhone).toList();
      } else if (_selectedFilter == 'ad') {
        _filteredMessages = _allMessages.where((m) => m.body?.startsWith('[QC]') ?? false).toList();
      } else if (_selectedFilter == 'otp') {
        _filteredMessages = _allMessages.where((m) {
          final body = m.body ?? '';
          return body.contains('[OTP]') && RegExp(r'\d{6}').hasMatch(body);
        }).toList();
      }
    });
  }

  Map<String, int> _getStatsByDate() {
    Map<String, int> stats = {};
    for (var msg in _allMessages) {
      if (msg.date != null) {
        String date = DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(msg.date!));
        stats[date] = (stats[date] ?? 0) + 1;
      }
    }
    return stats;
  }

  Map<String, int> _getStatsByMonth() {
    Map<String, int> stats = {};
    for (var msg in _allMessages) {
      if (msg.date != null) {
        String month = DateFormat('MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(msg.date!));
        stats[month] = (stats[month] ?? 0) + 1;
      }
    }
    return stats;
  }

  void _showOtpDialog(String body) {
    RegExp regExp = RegExp(r'\d{6}');
    String? otp = regExp.firstMatch(body)?.group(0);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mã OTP'),
        content: Text('Mã OTP là: $otp\n\nToàn bộ tin nhắn:\n$body'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int totalSms = _allMessages.length;
    int adCount = _allMessages.where((m) => m.body?.startsWith('[QC]') ?? false).length;
    int otpCount = _allMessages.where((m) {
      final body = m.body ?? '';
      return body.contains('[OTP]') && RegExp(r'\d{6}').hasMatch(body);
    }).length;
    Map<String, int> statsByDate = _getStatsByDate();
    Map<String, int> statsByMonth = _getStatsByMonth();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('SMS Analyzer'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Thống kê', icon: Icon(Icons.bar_chart)),
              Tab(text: 'Tin nhắn', icon: Icon(Icons.list)),
              Tab(text: 'Lọc', icon: Icon(Icons.filter_alt)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildStatsTab(totalSms, adCount, otpCount, statsByDate, statsByMonth),
            _buildMessagesTab(),
            _buildFilterTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsTab(int total, int ad, int otp, Map<String, int> byDate, Map<String, int> byMonth) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('TỔNG QUAN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(children: [
                        Text('$total', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue)),
                        const Text('Tổng tin nhắn'),
                      ]),
                      Column(children: [
                        Text('$ad', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.orange)),
                        const Text('Quảng cáo [QC]'),
                      ]),
                      Column(children: [
                        Text('$otp', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green)),
                        const Text('Mã OTP'),
                      ]),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Thống kê theo ngày', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...byDate.entries.map((entry) => Card(
            child: ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text(entry.key),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(20)),
                child: Text('${entry.value} tin nhắn', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          )),
          const SizedBox(height: 16),
          const Text('Thống kê theo tháng', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...byMonth.entries.map((entry) => Card(
            child: ListTile(
              leading: const Icon(Icons.date_range),
              title: Text(entry.key),
              trailing: Text('${entry.value} tin nhắn'),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildMessagesTab() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_filteredMessages.isEmpty) return const Center(child: Text('Không có tin nhắn nào'));

    return ListView.builder(
      itemCount: _filteredMessages.length,
      itemBuilder: (context, index) {
        SmsMessage msg = _filteredMessages[index];
        bool isOtp = msg.body?.contains('[OTP]') ?? false;
        bool isAd = msg.body?.startsWith('[QC]') ?? false;

        Color? cardColor;
        if (isOtp) cardColor = Colors.green.shade50;
        if (isAd) cardColor = Colors.orange.shade50;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: cardColor,
          child: ListTile(
            leading: isOtp
                ? const Icon(Icons.security, color: Colors.green)
                : (isAd ? const Icon(Icons.campaign, color: Colors.orange) : const Icon(Icons.message)),
            title: Text(msg.body ?? 'Không có nội dung', maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Từ: ${msg.address ?? 'Không rõ'}'),
                if (msg.date != null)
                  Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(DateTime.fromMillisecondsSinceEpoch(msg.date!)),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
            trailing: isOtp
                ? ElevatedButton.icon(
              onPressed: () => _showOtpDialog(msg.body ?? ''),
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Lấy OTP'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            )
                : null,
          ),
        );
      },
    );
  }

  Widget _buildFilterTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: DropdownButtonFormField<String>(
            value: _selectedFilter,
            items: const [
              DropdownMenuItem(value: 'all', child: Text('📋 Tất cả tin nhắn')),
              DropdownMenuItem(value: 'phone', child: Text('📞 Tin nhắn từ số cụ thể')),
              DropdownMenuItem(value: 'ad', child: Text('📢 Tin nhắn quảng cáo [QC]')),
              DropdownMenuItem(value: 'otp', child: Text('🔐 Tin nhắn OTP')),
            ],
            onChanged: (value) {
              setState(() {
                _selectedFilter = value!;
                if (_selectedFilter != 'phone') {
                  _filterMessages();
                }
              });
            },
            decoration: InputDecoration(
              labelText: 'Chọn bộ lọc',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        if (_selectedFilter == 'phone')
          Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<String>(
              value: _selectedPhone.isEmpty ? null : _selectedPhone,
              hint: const Text('Chọn số điện thoại'),
              items: _phoneNumbers.map((phone) {
                return DropdownMenuItem(value: phone, child: Text(phone));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedPhone = value!;
                  _filterMessages();
                });
              },
              decoration: InputDecoration(
                labelText: 'Danh sách số',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        if (_selectedFilter != 'all' && _selectedFilter != 'phone')
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: _filterMessages,
              icon: const Icon(Icons.filter_list),
              label: const Text('Áp dụng bộ lọc'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            ),
          ),
        if (_selectedFilter == 'phone' && _selectedPhone.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Tìm thấy ${_filteredMessages.length} tin nhắn từ số $_selectedPhone',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }
}