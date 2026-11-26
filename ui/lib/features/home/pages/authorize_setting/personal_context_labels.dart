import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class PersonalContextLabel {
  const PersonalContextLabel(
    this.id,
    this.icon,
    this.ar,
    this.en,
    this.arDetail,
    this.enDetail,
  );
  final String id;
  final IconData icon;
  final String ar;
  final String en;
  final String arDetail;
  final String enDetail;
}

const personalContextLabels = [
  PersonalContextLabel(
    'calendar_read',
    LucideIcons.calendar,
    'قراءة التقويم',
    'Read calendars',
    'استعلم عن التقاويم والأحداث المحفوظة على هذا الجهاز.',
    'Query calendars and events stored on this device.',
  ),
  PersonalContextLabel(
    'calendar_write',
    LucideIcons.calendar,
    'إدارة أحداث التقويم',
    'Manage calendar events',
    'أنشئ أو عدّل أو احذف الأحداث بناءً على طلبك؛ يتطلب أيضاً إذن قراءة التقويم.',
    'Create, update or delete events at your request; also requires calendar read access.',
  ),
  PersonalContextLabel(
    'contacts_read',
    LucideIcons.users,
    'قراءة جهات الاتصال',
    'Read contacts',
    'ابحث عن جهات الاتصال وأرقام الهواتف والبريد الإلكتروني والمؤسسات والعناوين.',
    'Look up contacts, phone numbers, emails, organizations and addresses.',
  ),
  PersonalContextLabel(
    'contacts_write',
    LucideIcons.users,
    'إدارة جهات الاتصال',
    'Manage contacts',
    'أنشئ أو عدّل أو احذف جهة اتصال محددة بناءً على طلبك؛ يتطلب أيضاً إذن قراءة جهات الاتصال.',
    'Create, update or delete a selected contact at your request; also requires contact read access.',
  ),
  PersonalContextLabel(
    'notifications',
    LucideIcons.bell,
    'قراءة الإشعارات وسجلها',
    'Read notifications and history',
    'اقرأ الإشعارات الحالية واحتفظ محلياً بإشعارات آخر 7 أيام بحد أقصى 10000 إشعار. مستقل عن استلام إشعارات Doser AI.',
    'Read current notifications and keep up to 7 days / 10,000 observed notifications locally. Separate from receiving Omnibot notifications.',
  ),
  PersonalContextLabel(
    'app_usage',
    LucideIcons.clock,
    'استخدام التطبيقات',
    'App usage',
    'استعلم عن التطبيقات المستخدمة مؤخراً وإحصاءات الاستخدام من النظام.',
    'Query recently opened apps and system usage statistics.',
  ),
  PersonalContextLabel(
    'location',
    LucideIcons.mapPin,
    'الموقع',
    'Location',
    'اطلب تحديد الموقع مرة واحدة عند الحاجة. الموقع التقريبي كافٍ؛ لا يوجد تتبع مستمر.',
    'Request one location fix when needed. Approximate location works; no continuous tracking.',
  ),
  PersonalContextLabel(
    'background_location',
    LucideIcons.mapPin,
    'الموقع في الخلفية',
    'Location in the background',
    'اسمح بالموقع أولاً، ثم اختر «السماح طوال الوقت» في إعدادات النظام للاستعلامات الخلفية عند الحاجة.',
    'First allow location, then choose “Allow all the time” in system settings for on-demand background queries.',
  ),
  PersonalContextLabel(
    'media_visual',
    LucideIcons.image,
    'الصور والفيديو',
    'Photos and videos',
    'استعلم عن الأسماء والتواريخ، بما فيها الوصول إلى الصور المحددة فقط. تُقرأ محتويات الملفات عند الحاجة فقط.',
    'Query names and dates, including selected-only access. File contents are read only when needed.',
  ),
  PersonalContextLabel(
    'media_audio',
    LucideIcons.music,
    'الملفات الصوتية',
    'Audio files',
    'ابحث عن الملفات الصوتية بالاسم والنوع والتاريخ.',
    'Find audio files by name, type and date.',
  ),
  PersonalContextLabel(
    'documents',
    LucideIcons.folder,
    'الملفات والمجلدات المحددة',
    'Selected files and folders',
    'حدد المستندات أو المجلدات من منتقي النظام. يمكنك إزالة الأذونات من هنا.',
    'Select documents or folders in the system picker. You can remove the grants here.',
  ),
  PersonalContextLabel(
    'sms',
    LucideIcons.messageSquare,
    'قراءة الرسائل النصية',
    'Read SMS',
    'استعلم عن الرسائل النصية دون إرسالها. يعتمد توفر الإذن على النظام ومصدر التثبيت.',
    'Query SMS without sending messages. Permission availability depends on the system and installer.',
  ),
  PersonalContextLabel(
    'call_log',
    LucideIcons.phone,
    'قراءة سجل المكالمات',
    'Read call history',
    'استعلم عن أرقام الهواتف وأوقات المكالمات ومدتها. يعتمد توفر الإذن على النظام ومصدر التثبيت.',
    'Query phone numbers, call times and duration. Availability depends on the system and installer.',
  ),
  PersonalContextLabel(
    'environment',
    LucideIcons.smartphone,
    'بيئة الجهاز',
    'Device environment',
    'اقرأ البطارية والشحن ونوع الشبكة وحالة الشاشة ومخرج الصوت دون أذونات إضافية.',
    'Read battery, charging, network type, screen state and audio output without extra permissions.',
  ),
];
