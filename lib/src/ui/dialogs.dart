import 'dart:math';
import 'package:flutter/material.dart';

Future<String?> askCustomerNameDialog(BuildContext context) async {
  final controller = TextEditingController();
  const randomNames = <String>[
    'Бабл-ти батыр', 'Матча-мастер', 'Лимонадный хан', 'Айсти-бро', 'Смузи-качок',
    'Чайный джигит', 'Сладкий айран', 'Сиропный акын', 'Пломбирный самурай', 'Фруктовый султан',
    'Тропик-бала', 'Манго-босс', 'Арбузный романтик', 'Дыня-чемпион', 'Вишнёвый денди',
    'Персиковый хан', 'Грушевый философ', 'Ягодный казах', 'Клубничный бай', 'Шоколадный самсара',
    'Карамельный принц', 'Соковый гений', 'Леденец-балапан', 'Чайхана-босс', 'Мятный мудрец',
    'Вафельный магнат', 'Круасанчик для души', 'Десертный чемпион', 'Баурсачный краш', 'Кремовый джигит',
    'Шымкентский донер-босс', 'Алматинский смузи-красавчик', 'Карагандинский матча-мастер', 'Павлодарский бабл-ти батыр',
    'Актюбинский лимонадный хан', 'Кызылординский айсти-бро', 'Костанайский сиропный джигит', 'Таразский смузи-бай',
    'Семейский донерный чемпион', 'Атырауский энергетик-бала', 'Астанинский бабл-ти батыр', 'Астанинский смузи-босс',
    'Астанинский айсти-джигит', 'Астанинский донер-красавчик', 'Астанинский матча-мастер', 'Астанинский лимонадный султан',
    'Астанинский сиропчик-балапан', 'Астанинский чилли-босс', 'Астанинский сладкий хан', 'Астанинский фреш-бро',
  ];
  final random = Random();
  String pickRandom() => randomNames[random.nextInt(randomNames.length)];

  return showDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('Введите имя'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Например: Али',
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: IconButton(
                tooltip: 'Случайное имя',
                icon: const Icon(Icons.shuffle, color: Colors.black54),
                splashRadius: 20,
                onPressed: () => controller.text = pickRandom(),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEF3340),
            ),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF057A4C),
              foregroundColor: Colors.white,
            ),
            child: const Text('Продолжить'),
          ),
        ],
      );
    },
  );
}
