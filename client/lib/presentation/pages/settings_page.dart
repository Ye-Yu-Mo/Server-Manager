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
  final TextEditingController _serverUrlController = TextEditingController();
  final TextEditingController _apiTokenController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  String? _success;
  bool _autoRefresh = true;
  int _refreshInterval = 30;
  bool _showToken = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 加载服务器URL设置
      final serverUrl = prefs.getString('server_url') ?? 'http://127.0.0.1:9999/api/v1';
      _serverUrlController.text = serverUrl;

      // 加载API Token设置
      final apiToken = prefs.getString('api_token') ?? '';
      _apiTokenController.text = apiToken;

      // 加载自动刷新设置
      _autoRefresh = prefs.getBool('auto_refresh') ?? true;
      
      // 加载刷新间隔设置
      _refreshInterval = prefs.getInt('refresh_interval') ?? 30;

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = '加载设置失败: $e';
      });
    }
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _success = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final provider = Provider.of<NodeProvider>(context, listen: false);

      // 验证服务器URL格式
      String serverUrl = _serverUrlController.text.trim();
      if (serverUrl.isEmpty) {
        throw Exception('服务器URL不能为空');
      }

      if (!serverUrl.startsWith('http://') && !serverUrl.startsWith('https://')) {
        throw Exception('服务器URL必须以 http:// 或 https:// 开头');
      }

      // 确保包含API版本路径
      if (!serverUrl.contains('/api/v1')) {
        // 移除尾部斜杠避免双斜杠
        serverUrl = serverUrl.replaceAll(RegExp(r'/+$'), '');
        // 确保URL以斜杠结尾，然后添加api/v1
        if (!serverUrl.endsWith('/')) {
          serverUrl = '$serverUrl/';
        }
        serverUrl = '${serverUrl}api/v1';
      } else {
        // 如果已经包含api/v1，确保格式正确
        serverUrl = serverUrl.replaceAll(RegExp(r'/+$'), '');
      }

      // 保存设置
      await prefs.setString('server_url', serverUrl);
      await prefs.setString('api_token', _apiTokenController.text.trim());
      await prefs.setBool('auto_refresh', _autoRefresh);
      await prefs.setInt('refresh_interval', _refreshInterval);

      // 更新Provider中的服务器URL和Token
      print('🔧 保存的服务器URL: $serverUrl');
      provider.setBaseUrl(serverUrl);
      provider.setApiToken(_apiTokenController.text.trim());

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
      setState(() {
        _isLoading = false;
        _error = '保存设置失败: $e';
      });
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _success = null;
    });

    try {
      final provider = Provider.of<NodeProvider>(context, listen: false);
      String serverUrl = _serverUrlController.text.trim();

      if (serverUrl.isEmpty) {
        throw Exception('请先输入服务器URL');
      }

      // 确保包含API版本路径
      if (!serverUrl.contains('/api/v1')) {
        // 移除尾部斜杠避免双斜杠
        serverUrl = serverUrl.replaceAll(RegExp(r'/+$'), '');
        // 确保URL以斜杠结尾，然后添加api/v1
        if (!serverUrl.endsWith('/')) {
          serverUrl = '$serverUrl/';
        }
        serverUrl = '${serverUrl}api/v1';
      } else {
        // 如果已经包含api/v1，确保格式正确
        serverUrl = serverUrl.replaceAll(RegExp(r'/+$'), '');
      }

      // 临时设置URL和Token进行测试
      provider.setBaseUrl(serverUrl);
      provider.setApiToken(_apiTokenController.text.trim());

      final isHealthy = await provider.checkHealth();
      
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
      setState(() {
        _isLoading = false;
        _error = '连接测试失败: $e';
      });
    }
  }

  void _resetToDefaults() {
    _serverUrlController.text = 'http://127.0.0.1:9999/api/v1';
    _apiTokenController.text = '';
    _autoRefresh = true;
    _refreshInterval = 30;
    
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

  @override
  void dispose() {
    _serverUrlController.dispose();
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
            TextField(
              controller: _serverUrlController,
              decoration: const InputDecoration(
                labelText: '服务器URL',
                hintText: 'http://127.0.0.1:9999',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.dns),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),
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
                setState(() {
                  _autoRefresh = value;
                });
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
                    setState(() {
                      _refreshInterval = value;
                    });
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
