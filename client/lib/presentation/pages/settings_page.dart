import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/node_provider.dart';
import '../providers/theme_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _serverIpController = TextEditingController();
  final TextEditingController _serverPortController = TextEditingController();
  final TextEditingController _apiTokenController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  String? _success;
  bool _autoRefresh = true;
  int _refreshInterval = 30;
  bool _showToken = false;
  bool _useHttps = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 加载服务器URL设置
      final serverUrl = prefs.getString('server_url') ?? '';
      // 解析URL为IP和端口
      _parseUrlToFields(serverUrl);

      // 加载API Token设置
      final apiToken = prefs.getString('api_token') ?? '';
      _apiTokenController.text = apiToken;

      // 加载自动刷新设置
      _autoRefresh = prefs.getBool('auto_refresh') ?? true;
      
      // 加载刷新间隔设置
      _refreshInterval = prefs.getInt('refresh_interval') ?? 30;

      // 加载HTTPS设置
      _useHttps = prefs.getBool('use_https') ?? false;

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = '加载设置失败: $e';
      });
    }
  }

  /// 解析URL为IP和端口字段
  void _parseUrlToFields(String url) {
    try {
      final uri = Uri.parse(url);
      _serverIpController.text = uri.host;
      _serverPortController.text = uri.port.toString();
      _useHttps = uri.scheme == 'https';
    } catch (e) {
      // 如果解析失败，留空让用户填写
      _serverIpController.text = '';
      _serverPortController.text = '';
      _useHttps = false;
    }
  }

  /// 从字段构建完整的URL
  String _buildServerUrl() {
    final protocol = _useHttps ? 'https' : 'http';
    final ip = _serverIpController.text.trim();
    final port = _serverPortController.text.trim();
    
    if (ip.isEmpty || port.isEmpty) {
      throw Exception('服务器IP和端口不能为空');
    }
    
    // 验证IP地址格式
    if (!RegExp(r'^(\d{1,3}\.){3}\d{1,3}$').hasMatch(ip) && ip != 'localhost') {
      throw Exception('请输入有效的IP地址或localhost');
    }
    
    // 验证端口格式
    final portNum = int.tryParse(port);
    if (portNum == null || portNum < 1 || portNum > 65535) {
      throw Exception('请输入有效的端口号 (1-65535)');
    }
    
    return '$protocol://$ip:$port/api/v1';
  }

  Future<void> _saveSettings() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
      _success = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 从字段构建完整的URL
      final serverUrl = _buildServerUrl();

      // 保存设置
      await prefs.setString('server_url', serverUrl);
      await prefs.setString('api_token', _apiTokenController.text.trim());
      await prefs.setBool('auto_refresh', _autoRefresh);
      await prefs.setInt('refresh_interval', _refreshInterval);
      await prefs.setBool('use_https', _useHttps);

      // 在setState之前获取Provider引用
      if (!mounted) return;
      final provider = Provider.of<NodeProvider>(context, listen: false);
      
      // 更新Provider中的服务器URL和Token
      provider.setBaseUrl(serverUrl);
      provider.setApiToken(_apiTokenController.text.trim());

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _success = '设置保存成功';
      });

      // 3秒后清除成功消息
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _success = null;
          });
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = '保存设置失败: $e';
      });
    }
  }

  Future<void> _testConnection() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
      _success = null;
    });

    try {
      final provider = Provider.of<NodeProvider>(context, listen: false);
      
      // 从字段构建完整的URL
      final serverUrl = _buildServerUrl();

      // 临时设置URL和Token进行测试
      provider.setBaseUrl(serverUrl);
      provider.setApiToken(_apiTokenController.text.trim());

      final isHealthy = await provider.checkHealth();
      
      if (!mounted) return;
      if (isHealthy) {
        setState(() {
          _isLoading = false;
          _success = '连接测试成功！服务器运行正常';
        });
      } else {
        throw Exception('连接测试失败：服务器无响应');
      }

      // 3秒后清除成功消息
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _success = null;
          });
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = '连接测试失败: $e';
      });
    }
  }

  void _resetToDefaults() {
    _serverIpController.text = '';
    _serverPortController.text = '';
    _apiTokenController.text = '';
    _autoRefresh = true;
    _refreshInterval = 30;
    _useHttps = false;
    
    setState(() {
      _error = null;
      _success = '已重置为默认设置';
    });

    // 3秒后清除成功消息
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _success = null;
        });
      }
    });
  }

  /// 更新自动刷新设置
  void _updateAutoRefresh(bool value) {
    setState(() {
      _autoRefresh = value;
    });
    
    // 立即应用到NodeProvider
    final provider = Provider.of<NodeProvider>(context, listen: false);
    provider.setAutoRefresh(_autoRefresh, interval: _refreshInterval);
  }

  /// 更新刷新间隔设置
  void _updateRefreshInterval(int value) {
    setState(() {
      _refreshInterval = value;
    });
    
    // 立即应用到NodeProvider
    final provider = Provider.of<NodeProvider>(context, listen: false);
    provider.setAutoRefresh(_autoRefresh, interval: _refreshInterval);
  }

  @override
  void dispose() {
    _serverIpController.dispose();
    _serverPortController.dispose();
    _apiTokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
            tooltip: '保存设置',
          ),
        ],
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) _buildErrorBanner(),
          if (_success != null) _buildSuccessBanner(),
          _buildServerSettingsCard(),
          const SizedBox(height: 16),
          _buildAppSettingsCard(),
          const SizedBox(height: 16),
          _buildActionsCard(),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red),
      ),
      child: Row(
        children: [
          const Icon(Icons.error, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _success!,
              style: const TextStyle(color: Colors.green),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServerSettingsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '服务器设置',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // IP地址输入
            TextField(
              controller: _serverIpController,
              decoration: const InputDecoration(
                labelText: '服务器IP地址',
                hintText: '例如: 192.168.1.100 或 localhost',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.dns),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),
            
            // 端口输入
            TextField(
              controller: _serverPortController,
              decoration: const InputDecoration(
                labelText: '服务器端口',
                hintText: '例如: 20001',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.settings_ethernet),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            
            // HTTPS开关
            SwitchListTile(
              title: const Text('使用HTTPS'),
              subtitle: const Text('启用安全连接'),
              value: _useHttps,
              onChanged: (value) {
                setState(() {
                  _useHttps = value;
                });
              },
            ),
            const SizedBox(height: 16),
            
            // API Token输入
            TextField(
              controller: _apiTokenController,
              decoration: InputDecoration(
                labelText: 'API Token (可选)',
                hintText: '输入认证令牌',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.vpn_key),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showToken ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      _showToken = !_showToken;
                    });
                  },
                ),
              ),
              obscureText: !_showToken,
            ),
            const SizedBox(height: 16),
            
            // 测试连接按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _testConnection,
                icon: const Icon(Icons.wifi_tethering),
                label: const Text('测试连接'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppSettingsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '应用设置',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Consumer<ThemeProvider>(
              builder: (context, themeProvider, child) {
                return SwitchListTile(
                  title: const Text('暗黑模式'),
                  subtitle: const Text('启用深色主题界面'),
                  value: themeProvider.isDarkMode,
                  onChanged: (value) {
                    themeProvider.toggleTheme();
                  },
                );
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('自动刷新数据'),
              subtitle: const Text('启用后自动刷新节点和监控数据'),
              value: _autoRefresh,
              onChanged: (value) {
                _updateAutoRefresh(value);
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              title: const Text('刷新间隔'),
              subtitle: Text('$_refreshInterval 秒'),
              trailing: DropdownButton<int>(
                value: _refreshInterval,
                items: const [
                  DropdownMenuItem(value: 15, child: Text('15秒')),
                  DropdownMenuItem(value: 30, child: Text('30秒')),
                  DropdownMenuItem(value: 60, child: Text('1分钟')),
                  DropdownMenuItem(value: 300, child: Text('5分钟')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    _updateRefreshInterval(value);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: _saveSettings,
              icon: const Icon(Icons.save),
              label: const Text('保存设置'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _resetToDefaults,
              icon: const Icon(Icons.restart_alt),
              label: const Text('恢复默认设置'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
