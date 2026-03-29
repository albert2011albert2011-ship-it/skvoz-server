import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Политика конфиденциальности'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('1. Общие положения'),
            _buildText(
              'Мессенджер "Сквозь" уважает вашу конфиденциальность. '
              'Это приложение работает без центрального сервера, используя mesh-сеть '
              'для передачи сообщений между устройствами.',
            ),
            const SizedBox(height: 20),
            
            _buildSectionTitle('2. Сбор данных'),
            _buildText(
              'Мы НЕ собираем, не храним и не передаем следующие данные:\n'
              '• Ваши личные сообщения\n'
              '• Контакты\n'
              '• Местоположение\n'
              '• История переписки\n\n'
              'При регистрации вы указываете:\n'
              '• Имя (отображается другим пользователям)\n'
              '• Никнейм (уникальный идентификатор)\n'
              '• Email (необязательно, не проверяется)\n'
              '• Телефон (необязательно, не проверяется)',
            ),
            const SizedBox(height: 20),
            
            _buildSectionTitle('3. Как работают сообщения'),
            _buildText(
              'Сообщения передаются напрямую между устройствами через:\n'
              '• Bluetooth\n'
              '• Wi-Fi Direct\n'
              '• Mesh-сеть (через другие устройства)\n\n'
              'Сообщения могут проходить через устройства других пользователей '
              'в зашифрованном виде для доставки получателю.',
            ),
            const SizedBox(height: 20),
            
            _buildSectionTitle('4. Хранение данных'),
            _buildText(
              'Все данные хранятся ТОЛЬКО на вашем устройстве:\n'
              '• История сообщений\n'
              '• Контакты\n'
              '• Профиль пользователя\n\n'
              'При удалении приложения все данные будут потеряны.',
            ),
            const SizedBox(height: 20),
            
            _buildSectionTitle('5. Безопасность'),
            _buildText(
              '• Сообщения передаются без центрального сервера\n'
              '• Нет облачного хранения\n'
              '• Устройства сами маршрутизируют сообщения\n'
              '• Рекомендуется использовать дополнительное шифрование',
            ),
            const SizedBox(height: 20),
            
            _buildSectionTitle('6. Разрешения приложения'),
            _buildText(
              'Приложение запрашивает следующие разрешения:\n'
              '• Bluetooth - для связи с ближайшими устройствами\n'
              '• Wi-Fi - для Wi-Fi Direct соединения\n'
              '• Хранилище - для сохранения файлов и медиа\n'
              '• Местоположение (требуется Android для Bluetooth)',
            ),
            const SizedBox(height: 20),
            
            _buildSectionTitle('7. Изменения политики'),
            _buildText(
              'Мы можем обновлять эту политику конфиденциальности. '
              'Актуальная версия всегда доступна в приложении.',
            ),
            const SizedBox(height: 20),
            
            _buildSectionTitle('8. Контакты'),
            _buildText(
              'По вопросам конфиденциальности обращайтесь:\n'
              'Email: privacy@skvoz.app',
            ),
            const SizedBox(height: 40),
            
            Center(
              child: Text(
                'Версия 1.0.0',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
  
  Widget _buildText(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        height: 1.5,
        color: Colors.grey[800],
      ),
    );
  }
}
