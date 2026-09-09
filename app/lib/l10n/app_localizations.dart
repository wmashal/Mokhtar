import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appName.
  ///
  /// In ar, this message translates to:
  /// **'مختار'**
  String get appName;

  /// No description provided for @loginTitle.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get loginTitle;

  /// No description provided for @phoneNumber.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف'**
  String get phoneNumber;

  /// No description provided for @enterCode.
  ///
  /// In ar, this message translates to:
  /// **'أدخل الرمز'**
  String get enterCode;

  /// No description provided for @sendCode.
  ///
  /// In ar, this message translates to:
  /// **'إرسال'**
  String get sendCode;

  /// No description provided for @login.
  ///
  /// In ar, this message translates to:
  /// **'دخول'**
  String get login;

  /// No description provided for @codeHint.
  ///
  /// In ar, this message translates to:
  /// **'اطلب الرمز من المختار'**
  String get codeHint;

  /// No description provided for @invalidCode.
  ///
  /// In ar, this message translates to:
  /// **'الرمز غير صحيح أو منتهي'**
  String get invalidCode;

  /// No description provided for @home.
  ///
  /// In ar, this message translates to:
  /// **'الرئيسية'**
  String get home;

  /// No description provided for @finance.
  ///
  /// In ar, this message translates to:
  /// **'المالية'**
  String get finance;

  /// No description provided for @meters.
  ///
  /// In ar, this message translates to:
  /// **'العدادات'**
  String get meters;

  /// No description provided for @meetings.
  ///
  /// In ar, this message translates to:
  /// **'الاجتماعات'**
  String get meetings;

  /// No description provided for @announcements.
  ///
  /// In ar, this message translates to:
  /// **'الإعلانات'**
  String get announcements;

  /// No description provided for @myBalance.
  ///
  /// In ar, this message translates to:
  /// **'رصيدي'**
  String get myBalance;

  /// No description provided for @buildingStatement.
  ///
  /// In ar, this message translates to:
  /// **'كشف حساب المبنى'**
  String get buildingStatement;

  /// No description provided for @myStatement.
  ///
  /// In ar, this message translates to:
  /// **'كشف حسابي'**
  String get myStatement;

  /// No description provided for @addTransaction.
  ///
  /// In ar, this message translates to:
  /// **'إضافة حركة'**
  String get addTransaction;

  /// No description provided for @payment.
  ///
  /// In ar, this message translates to:
  /// **'دفعة'**
  String get payment;

  /// No description provided for @charge.
  ///
  /// In ar, this message translates to:
  /// **'رسوم'**
  String get charge;

  /// No description provided for @expense.
  ///
  /// In ar, this message translates to:
  /// **'مصروف'**
  String get expense;

  /// No description provided for @amount.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ'**
  String get amount;

  /// No description provided for @category.
  ///
  /// In ar, this message translates to:
  /// **'التصنيف'**
  String get category;

  /// No description provided for @note.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظة'**
  String get note;

  /// No description provided for @save.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد'**
  String get confirm;

  /// No description provided for @units.
  ///
  /// In ar, this message translates to:
  /// **'الشقق'**
  String get units;

  /// No description provided for @unitNumber.
  ///
  /// In ar, this message translates to:
  /// **'رقم الشقة'**
  String get unitNumber;

  /// No description provided for @residentName.
  ///
  /// In ar, this message translates to:
  /// **'اسم الساكن'**
  String get residentName;

  /// No description provided for @monthlyFee.
  ///
  /// In ar, this message translates to:
  /// **'الاشتراك الشهري'**
  String get monthlyFee;

  /// No description provided for @newReadingRound.
  ///
  /// In ar, this message translates to:
  /// **'جولة قراءة جديدة'**
  String get newReadingRound;

  /// No description provided for @currentReading.
  ///
  /// In ar, this message translates to:
  /// **'القراءة الحالية'**
  String get currentReading;

  /// No description provided for @previousReading.
  ///
  /// In ar, this message translates to:
  /// **'القراءة السابقة'**
  String get previousReading;

  /// No description provided for @consumption.
  ///
  /// In ar, this message translates to:
  /// **'الاستهلاك'**
  String get consumption;

  /// No description provided for @cost.
  ///
  /// In ar, this message translates to:
  /// **'التكلفة'**
  String get cost;

  /// No description provided for @issueInvoices.
  ///
  /// In ar, this message translates to:
  /// **'إصدار الفواتير'**
  String get issueInvoices;

  /// No description provided for @inviteResident.
  ///
  /// In ar, this message translates to:
  /// **'دعوة ساكن'**
  String get inviteResident;

  /// No description provided for @inviteCode.
  ///
  /// In ar, this message translates to:
  /// **'رمز الدعوة'**
  String get inviteCode;

  /// No description provided for @shareCodeHint.
  ///
  /// In ar, this message translates to:
  /// **'أعطِ هذا الرمز للساكن'**
  String get shareCodeHint;

  /// No description provided for @newMeeting.
  ///
  /// In ar, this message translates to:
  /// **'اجتماع جديد'**
  String get newMeeting;

  /// No description provided for @meetingTitle.
  ///
  /// In ar, this message translates to:
  /// **'عنوان الاجتماع'**
  String get meetingTitle;

  /// No description provided for @meetingLocation.
  ///
  /// In ar, this message translates to:
  /// **'المكان'**
  String get meetingLocation;

  /// No description provided for @attending.
  ///
  /// In ar, this message translates to:
  /// **'سأحضر'**
  String get attending;

  /// No description provided for @notAttending.
  ///
  /// In ar, this message translates to:
  /// **'لن أحضر'**
  String get notAttending;

  /// No description provided for @newAnnouncement.
  ///
  /// In ar, this message translates to:
  /// **'إعلان جديد'**
  String get newAnnouncement;

  /// No description provided for @logout.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get logout;

  /// No description provided for @noData.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد بيانات'**
  String get noData;

  /// No description provided for @error.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ'**
  String get error;

  /// No description provided for @retry.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get retry;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
