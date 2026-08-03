import 'tutorial_step.dart';

/// The guided tour of the Estimation flow, in Urdu.
///
/// Written for a workshop owner, not a software user: it uses the words the
/// trade already uses (کالر، سیکشن، کٹنگ، لینتھ، ریٹ) rather than translating
/// the English labels. Nothing here is a translation of existing app copy --
/// it is written from scratch for the tour.
///
/// Each step names the screen it belongs to and, where it points at something,
/// the id of the [TutorialTarget] wrapping that widget.
const List<TutorialStep> estimationTutorialSteps = <TutorialStep>[
  // ---------------------------------------------------------------- Home
  TutorialStep(
    screen: TutorialScreen.home,
    title: 'خوش آمدید',
    body:
        'آئیے آپ کو Quick AL چلانا سکھاتے ہیں۔ ہم مل کر ایک پورا اندازہ '
        'بنائیں گے — ونڈو کے ناپ سے لے کر بل تک۔ کسی بھی وقت اوپر '
        '"چھوڑ دیں" دبا کر باہر نکل سکتے ہیں۔',
  ),
  TutorialStep(
    screen: TutorialScreen.home,
    targetId: 'home.estimation',
    title: 'ایسٹیمیشن',
    body:
        'یہ آپشن ایلومینیم ونڈوز اور ڈورز میں لگنے والے میٹریل کا اندازہ '
        'لگاتا ہے۔ یہ لینتھیں بناتا ہے اور ضیاع (ویسٹیج) کو بہت حد تک کم کر '
        'دیتا ہے۔ ہر سیکشن کا ریٹ خود بخود لگ جاتا ہے، مال کی سمری بھی ملتی '
        'ہے، اور آخر میں لیبر، شیشہ، ہارڈویئر اور ڈسکاؤنٹ لگا کر بل بھی بن '
        'جاتا ہے۔ ہر مرحلے پر PDF ڈاؤن لوڈ کرنے کا آپشن موجود ہے۔',
    tapHint: 'ایسٹیمیشن پر دبائیں',
    requiresTap: true,
  ),

  // ------------------------------------------------------- Window library
  TutorialStep(
    screen: TutorialScreen.windowLibrary,
    title: 'ونڈو لائبریری',
    body:
        'یہ ونڈو لائبریری ہے۔ یہاں سے آپ وہ ونڈو چنتے ہیں جو آپ کو بنانی ہے۔ '
        'ہر قسم کی ونڈو اور ڈور یہاں موجود ہے۔',
  ),
  TutorialStep(
    screen: TutorialScreen.windowLibrary,
    targetId: 'library.sliding',
    title: 'سلائیڈنگ ونڈو',
    body:
        'مثال کے طور پر ہم سلائیڈنگ ونڈو لیتے ہیں — یہی سب سے زیادہ بنتی ہے۔ '
        'آپ اپنی ضرورت کے مطابق کوئی بھی چن سکتے ہیں۔',
    tapHint: 'سلائیڈنگ ونڈو پر دبائیں',
    requiresTap: true,
  ),

  // --------------------------------------------------------- Window input
  TutorialStep(
    screen: TutorialScreen.windowInput,
    targetId: 'input.winNo',
    title: 'ونڈو نمبر',
    body:
        'ہر ونڈو کو ایک نمبر ملتا ہے۔ اسی نمبر سے آپ بعد میں کٹنگ رپورٹ اور '
        'بل میں پہچانتے ہیں کہ کون سا ٹکڑا کس ونڈو کا ہے۔',
  ),
  TutorialStep(
    screen: TutorialScreen.windowInput,
    targetId: 'input.collarCards',
    title: 'کالر کارڈز',
    body:
        'یہ کالر کارڈز ہیں۔ ان میں سے وہ ڈیزائن چنیں جو آپ کی ونڈو سے ملتا '
        'ہو۔ نیلی لکیر کا مطلب ہے وہاں کالر ہے، اور سرخ لکیر کا مطلب ہے وہاں '
        'کالر نہیں ہے۔ سلائیڈنگ ونڈو کے لیے کل ۱۴ ڈیزائن ہیں — یہ ہر ممکن '
        'صورت کو سنبھال لیتے ہیں۔',
  ),
  TutorialStep(
    screen: TutorialScreen.windowInput,
    targetId: 'input.sizes',
    title: 'ناپ درج کریں',
    body:
        'یہاں ونڈو کا ناپ لکھیں — اونچائی اور چوڑائی۔ ناپ اسی یونٹ میں جائے '
        'گا جو آپ نے چنا ہے: سینٹی میٹر، انچ یا فٹ۔',
  ),
  TutorialStep(
    screen: TutorialScreen.windowInput,
    targetId: 'input.unit',
    title: 'یونٹ',
    body:
        'یونٹ آپ اپنی مرضی سے چن سکتے ہیں، اور یہ سیٹنگ ہر ونڈو کے لیے الگ '
        'بھی بدلی جا سکتی ہے۔ ایک ونڈو فٹ میں اور دوسری انچ میں — کوئی حرج '
        'نہیں۔',
  ),
  TutorialStep(
    screen: TutorialScreen.windowInput,
    targetId: 'input.description',
    title: 'تفصیل (اختیاری)',
    body:
        'یہاں آپ نشانی کے لیے کچھ بھی لکھ سکتے ہیں، مثلاً "واش روم کی ونڈو"۔ '
        'یہ لازمی نہیں — خالی بھی چھوڑ سکتے ہیں۔',
  ),
  TutorialStep(
    screen: TutorialScreen.windowInput,
    targetId: 'input.quantity',
    title: 'تعداد',
    body:
        'اگر اسی ناپ کی کئی ونڈوز بنانی ہیں تو یہاں تعداد لکھ دیں۔ ایک ہی '
        'ونڈو ہو تو اسے خالی چھوڑ دیں۔',
  ),
  TutorialStep(
    screen: TutorialScreen.windowInput,
    targetId: 'input.threeDots',
    title: 'سائیڈ بار',
    body: 'اوپر یہ تین نقطوں والا بٹن سائیڈ بار کھولتا ہے۔',
    tapHint: 'تین نقطوں پر دبائیں',
    requiresTap: true,
  ),
  TutorialStep(
    screen: TutorialScreen.windowInput,
    targetId: 'input.sidebarSections',
    title: 'سیکشنز',
    body:
        'یہاں آپ کو، چنے ہوئے کالر کے مطابق، اس ونڈو میں لگنے والے ہر سیکشن '
        'کا بٹن ملے گا۔ کسی بھی سیکشن کو دبائیں تو ونڈو کے نقشے میں وہی حصہ '
        'نمایاں ہو جائے گا جہاں وہ سیکشن لگتا ہے۔',
  ),
  TutorialStep(
    screen: TutorialScreen.windowInput,
    targetId: 'input.next',
    title: 'آگے بڑھیں',
    body:
        'ساری ونڈوز درج کر لیں تو یہ تیر والا بٹن دبائیں۔ اس سے لینتھ '
        'آپٹیمائزیشن کھل جائے گی۔',
    tapHint: 'اگلے صفحے پر جائیں',
    requiresTap: true,
  ),

  // --------------------------------------------------- Length optimization
  TutorialStep(
    screen: TutorialScreen.lengthOptimization,
    title: 'لینتھ آپٹیمائزیشن',
    body:
        'یہ سب سے اہم صفحہ ہے۔ یہاں ایپ خود حساب لگاتی ہے کہ کون سا ٹکڑا کس '
        'لینتھ میں سے کاٹا جائے تاکہ ضیاع کم سے کم ہو۔',
  ),
  TutorialStep(
    screen: TutorialScreen.lengthOptimization,
    targetId: 'lo.sectionTabs',
    title: 'سیکشن چنیں',
    body:
        'یہ سیکشن کے بٹن ہیں۔ ابھی جو سیکشن چنا ہوا ہے، نیچے اسی کی لینتھوں '
        'کی تفصیل دکھائی جا رہی ہے۔ دوسرا سیکشن دیکھنا ہو تو اس کا بٹن دبا '
        'دیں۔',
  ),
  TutorialStep(
    screen: TutorialScreen.lengthOptimization,
    targetId: 'lo.groups',
    title: 'گروپ',
    body:
        'گروپ کا مطلب ہے ایک جیسی لینتھوں کا مجموعہ۔ اگر ایک ہی ناپ کی کئی '
        'لینتھیں کٹنی ہیں تو وہ ایک گروپ میں آ جاتی ہیں، تاکہ فہرست چھوٹی اور '
        'سمجھنے میں آسان رہے۔',
  ),
  TutorialStep(
    screen: TutorialScreen.lengthOptimization,
    targetId: 'lo.lengths',
    title: 'لینتھ',
    body:
        'لینتھ وہ پوری راڈ ہے جو آپ ڈیلر سے خریدتے ہیں۔ ایپ بتاتی ہے کہ اس '
        'سیکشن کی کتنی لینتھیں لگیں گی اور ہر لینتھ میں سے کیا کیا نکلے گا۔',
  ),
  TutorialStep(
    screen: TutorialScreen.lengthOptimization,
    targetId: 'lo.cutsColumn',
    title: 'کٹ پیس',
    body:
        'یہاں دکھایا جا رہا ہے کہ ایک لینتھ بنانے کے لیے کس ونڈو کے کون کون '
        'سے ٹکڑے استعمال ہوئے ہیں۔ ساتھ میں کٹس والا کالم بھی دیکھیں — وہی آپ '
        'کے کاریگر کے لیے اصل کٹنگ لسٹ ہے۔',
  ),
  TutorialStep(
    screen: TutorialScreen.lengthOptimization,
    targetId: 'lo.pdf',
    title: 'PDF',
    body:
        'یہ بٹن پوری رپورٹ PDF بنا کر آپ کے فون کے ڈاؤن لوڈ فولڈر میں محفوظ '
        'کر دیتا ہے۔ وہیں سے آپ اسے واٹس ایپ پر بھیج سکتے ہیں یا پرنٹ کروا '
        'سکتے ہیں۔',
  ),
  TutorialStep(
    screen: TutorialScreen.lengthOptimization,
    targetId: 'lo.recalculate',
    title: 'دوبارہ حساب',
    body:
        'اگر ڈیلر کے پاس ہر لینتھ موجود نہ ہو تو یہ بٹن دبائیں۔ اگلے صفحے پر '
        'آپ شرط لگا سکتے ہیں۔',
    tapHint: 'دوبارہ حساب پر دبائیں',
    requiresTap: true,
  ),

  // ------------------------------------------------ Section recalculation
  TutorialStep(
    screen: TutorialScreen.sectionRecalculation,
    title: 'شرط لگائیں',
    body:
        'یہ صفحہ اصل دکان کے حساب سے ہے۔ یہاں آپ بتا سکتے ہیں کہ ڈیلر کے پاس '
        'کون سی لینتھ پڑی ہے اور کون سی ختم ہو چکی ہے۔ مثلاً ۱۴ فٹ والی ختم '
        'ہو گئی ہے تو اس کے سامنے ۰ لکھ دیں۔ اگر صرف ایک ہی پڑی ہے تو ۱ لکھ '
        'دیں۔ ایپ باقی لینتھوں میں سے ہی حساب بنا دے گی۔',
  ),

  // ---------------------------------------------------- Material selection
  TutorialStep(
    screen: TutorialScreen.materialSelection,
    title: 'گیج اور رنگ',
    body:
        'یہاں ایپ آپ سے ایلومینیم کا گیج اور رنگ پوچھتی ہے۔ ریٹ اسی کے مطابق '
        'لگیں گے، اس لیے وہی چنیں جو آپ اصل میں استعمال کر رہے ہیں۔',
  ),

  // -------------------------------------------------------- Material table
  TutorialStep(
    screen: TutorialScreen.materialTable,
    title: 'مال کی سمری',
    body:
        'یہاں آپ اس پروجیکٹ میں لگنے والے تمام میٹریل کی سمری دیکھ سکتے ہیں۔ '
        'چاہیں تو یہیں سے آرڈر بھی کر سکتے ہیں، لیکن ہمارا مشورہ نہیں — یہ '
        'کام فیبریکیشن میں زیادہ بہتر طریقے سے ہوتا ہے۔',
  ),

  // ----------------------------------------------------------- Bill inputs
  TutorialStep(
    screen: TutorialScreen.billInputs,
    title: 'بل کی تفصیل',
    body:
        'اب بل بنانے کا مرحلہ۔ شیشے کا ریٹ فی مربع فٹ کے حساب سے لکھیں، اسی '
        'طرح لیبر کا ریٹ اور ہارڈویئر فی ونڈو۔ ڈسکاؤنٹ، اضافی خرچ اور ایڈوانس '
        'بھی یہیں لکھ سکتے ہیں۔ جو خانہ لاگو نہ ہو، اسے خالی چھوڑ دیں۔',
  ),

  // ----------------------------------------------------------- Actual bill
  TutorialStep(
    screen: TutorialScreen.actualBill,
    title: 'تیار بل',
    body:
        'یہ آپ کا تیار بل ہے۔ اوپر پورے پروجیکٹ کا خلاصہ ہے — کل رقبہ، مال کی '
        'لاگت، لیبر، شیشہ اور کل رقم۔',
  ),
  TutorialStep(
    screen: TutorialScreen.actualBill,
    targetId: 'bill.editSection',
    title: 'قیمتیں بدلی جا سکتی ہیں',
    body:
        'کوئی بھی قیمت پسند نہ آئے تو یہیں سے بدل سکتے ہیں — ہر حصے کے اوپر '
        'ایڈٹ کا بٹن موجود ہے۔ ریٹ بھی اسی طرح بدلے جا سکتے ہیں، اور بل خود '
        'دوبارہ حساب کر لے گا۔',
  ),
  TutorialStep(
    screen: TutorialScreen.actualBill,
    title: 'بس اتنا ہی',
    body:
        'ایسٹیمیشن کا پورا سفر مکمل ہوا۔ یہ رہنمائی آپ کبھی بھی دوبارہ دیکھ '
        'سکتے ہیں — ہوم پیج پر "ٹیوٹوریل شروع کریں" کا بٹن ہے، اور سیٹنگز میں '
        'بھی موجود ہے۔',
  ),
];
