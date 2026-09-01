import 'tutorial_step.dart';

/// The guided tour of the Estimation flow, in Urdu.
///
/// Written for a workshop owner, not a software user: it uses the words the
/// trade already uses (کالر، سیکشن، کٹنگ، لینتھ، ریٹ) rather than translating
/// the English labels. Nothing here is a translation of existing app copy --
/// it is written from scratch for the tour.
///
/// The tour does not just describe the screens; it makes the user work through
/// a real estimate. Wherever the user has to act -- pick a window, type a size,
/// press PDF -- the step sets [TutorialStep.requiresTap] so the tour waits for
/// the real tap instead of moving on by itself.
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
        'جاتا ہے۔',
    tapHint: 'ایسٹیمیشن پر دبائیں',
    requiresTap: true,
  ),

  // --------------------------------------------------------- Project menu
  TutorialStep(
    screen: TutorialScreen.projectMenu,
    targetId: 'menu.createProject',
    title: 'نیا پروجیکٹ',
    body:
        'ہر کام ایک پروجیکٹ سے شروع ہوتا ہے۔ یہاں پروجیکٹ کا نام اور جگہ لکھیں '
        '— بعد میں اسی نام سے آپ اپنا کام دوبارہ کھول سکیں گے۔ پرانے پروجیکٹ '
        'نیچے فہرست میں ملیں گے۔',
    tapHint: 'نیا پروجیکٹ بنائیں',
    requiresTap: true,
  ),

  // ------------------------------------------------------- Window library
  TutorialStep(
    screen: TutorialScreen.windowLibrary,
    title: 'ونڈو لائبریری',
    body:
        'یہ ونڈو لائبریری ہے۔ یہاں سے آپ وہ ونڈو چنتے ہیں جو آپ نے بنانی ہے۔ '
        'ہر قسم کی ونڈو اور ڈور یہاں موجود ہے۔ سیکھنے کے لیے ہم سلائیڈنگ ونڈو '
        'لیں گے۔',
  ),
  TutorialStep(
    screen: TutorialScreen.windowLibrary,
    targetId: 'library.sliding',
    title: 'سلائیڈنگ ونڈو',
    body:
        'یہ رہی سلائیڈنگ ونڈو۔ اسی پر ہم پورا کام کر کے دکھائیں گے۔ اسے دبائیں '
        'تاکہ ناپ لکھنے والا صفحہ کھل جائے۔',
    tapHint: 'سلائیڈنگ ونڈو پر دبائیں',
    requiresTap: true,
  ),

  // --------------------------------------------------------- Window input
  TutorialStep(
    screen: TutorialScreen.windowInput,
    targetId: 'input.winNo',
    title: 'ونڈو نمبر',
    body:
        'یہ آپ کی ونڈو کا نمبر ہے۔ ہر ونڈو کو ایک نمبر ملتا ہے تاکہ بعد میں '
        'کٹنگ لسٹ اور بل میں پہچانا جا سکے کہ کون سا ناپ کس ونڈو کا تھا۔ '
        'سیٹنگز میں سے آپ اسے خودکار یا اپنے ہاتھ سے لکھنے والا بنا سکتے ہیں۔',
  ),
  TutorialStep(
    screen: TutorialScreen.windowInput,
    targetId: 'input.collarCards',
    title: 'کالر کی قسم',
    body:
        'یہ کارڈ آپ کی ونڈو کی شکل دکھاتا ہے۔ انگلی سے دائیں بائیں سرکائیں — '
        'دو کالر، تین کالر، چار کالر — اور جو آپ کی ونڈو ہے وہی سامنے رکھیں۔ '
        'جو کارڈ سامنے ہو گا، حساب اسی حساب سے لگے گا۔',
    tapHint: 'کارڈ کو دائیں سرکا کر دیکھیں',
  ),
  TutorialStep(
    screen: TutorialScreen.windowInput,
    targetId: 'input.unit',
    title: 'یونٹ',
    body:
        'سب سے پہلے یہ دیکھیں کہ آپ کس یونٹ میں ناپ لکھ رہے ہیں — فٹ، انچ یا '
        'سینٹی میٹر۔ یہ پہلے چھپا ہوا تھا، اسی لیے لوگ غلط یونٹ میں ناپ لکھ '
        'دیتے تھے۔ اب یہ ناپ والے خانوں کے ساتھ ہی موجود ہے۔',
  ),
  TutorialStep(
    screen: TutorialScreen.windowInput,
    targetId: 'input.sizes',
    title: 'ونڈو کا ناپ',
    body:
        'یہاں اونچائی اور چوڑائی لکھیں۔ یہی وہ ناپ ہے جس پر پوری کٹنگ کا حساب '
        'کھڑا ہے، اس لیے اطمینان سے لکھیں۔ ابھی اپنی ونڈو کا ناپ لکھ کر دیکھیں۔',
    tapHint: 'اونچائی اور چوڑائی لکھیں',
  ),
  TutorialStep(
    screen: TutorialScreen.windowInput,
    targetId: 'input.wheel',
    title: 'انچ اور سُتر کا پہیہ',
    body:
        'پورے فٹ کے ساتھ جو انچ یا سُتر بچتے ہیں وہ اس پہیے سے چنے جاتے ہیں — '
        'بالکل اِنچی ٹیپ کی طرح۔ اگر آپ کو ہاتھ سے لکھنا آسان لگتا ہے تو '
        'سیٹنگز میں جا کر اس پہیے کو ہٹا کر لکھنے والا خانہ لگا سکتے ہیں۔',
  ),
  TutorialStep(
    screen: TutorialScreen.windowInput,
    targetId: 'input.material',
    title: 'گیج اور رنگ',
    body:
        'یہ ونڈو کس مال کی بنے گی — گیج یعنی ایلومینیم کی موٹائی، اور اس کا '
        'رنگ۔ ہر ونڈو کا اپنا ہو سکتا ہے، اس لیے ایک ہی پروجیکٹ میں کچھ ونڈوز '
        '2mm اور کچھ 1.2mm میں رکھ سکتے ہیں۔ اگلی ونڈو میں یہی خود آ جائے گا، '
        'بدلنا ہو تو بدل دیجیے۔',
    tapHint: 'گیج اور رنگ چنیں',
  ),
  TutorialStep(
    screen: TutorialScreen.windowInput,
    targetId: 'input.description',
    title: 'تفصیل',
    body:
        'یہ خانہ اختیاری ہے۔ یہاں ونڈو کی پہچان لکھیں — جیسے "باتھ روم" یا '
        '"سامنے والا کمرہ"۔ یہی تفصیل بعد میں کٹنگ لسٹ اور بل میں چھپتی ہے، '
        'جس سے کاریگر کو فوراً پتہ چل جاتا ہے کہ یہ ونڈو کہاں لگنی ہے۔',
  ),
  TutorialStep(
    screen: TutorialScreen.windowInput,
    targetId: 'input.quantity',
    title: 'کتنی ونڈوز',
    body:
        'اگر بالکل اسی ناپ کی ایک سے زیادہ ونڈوز ہیں تو یہاں تعداد لکھ دیں — '
        'مثلاً 6۔ ایک ہی ناپ چھ بار لکھنے کی ضرورت نہیں، ایپ خود چھ ونڈوز بنا '
        'دے گی۔ خالی چھوڑیں تو ایک ہی ونڈو بنے گی۔ ابھی کوئی تعداد لکھ کر دیکھیں۔',
    tapHint: 'تعداد لکھیں',
  ),
  TutorialStep(
    screen: TutorialScreen.windowInput,
    targetId: 'input.save',
    title: 'محفوظ کریں',
    body:
        'ناپ مکمل ہو گیا۔ اب اسے محفوظ کریں تاکہ یہ ونڈو آپ کے پروجیکٹ میں '
        'شامل ہو جائے۔',
    tapHint: 'محفوظ کریں دبائیں',
    requiresTap: true,
  ),
  TutorialStep(
    screen: TutorialScreen.windowInput,
    targetId: 'input.sectionsButton',
    title: 'سیکشنز',
    body:
        'یہ بٹن ونڈو کے سیکشن کھولتا ہے۔ اسے دبائیں — سائیڈ سے ایک پینل کھلے گا۔',
    tapHint: 'سیکشنز پر دبائیں',
    requiresTap: true,
  ),
  TutorialStep(
    screen: TutorialScreen.windowInput,
    targetId: 'input.sidebarSections',
    title: 'سیکشن کے بٹن',
    body:
        'ان سیکشن بٹنوں کا مقصد یہ ہے کہ آپ کو دکھایا جائے کہ جو ونڈو آپ نے چنی '
        'ہے، اس کا یہ سیکشن کہاں استعمال ہو رہا ہے۔ کسی ایک سیکشن پر دبائیں — '
        'ونڈو کی تصویر میں وہی حصہ نمایاں ہو جائے گا۔',
    tapHint: 'کسی ایک سیکشن پر دبائیں',
    requiresTap: true,
  ),
  TutorialStep(
    screen: TutorialScreen.windowInput,
    title: 'پینل بند کریں',
    body:
        'دیکھ لیا؟ اب اس پینل سے باہر آنے کے لیے پینل کے پہلو میں، اصل صفحے پر '
        'کہیں بھی انگلی رکھیں — پینل خود بند ہو جائے گا۔',
    tapHint: 'صفحے کے کھلے حصے پر دبائیں',
  ),
  TutorialStep(
    screen: TutorialScreen.windowInput,
    targetId: 'input.next',
    title: 'اگلا قدم',
    body:
        'اگر آپ کو مزید ونڈوز ڈالنی ہوں تو یہیں سے ڈالتے رہیں۔ ابھی ہم آگے چلتے '
        'ہیں — یہ تیر دبائیں۔',
    tapHint: 'آگے والا تیر دبائیں',
    requiresTap: true,
  ),

  // ----------------------------------------------------------- Review list
  TutorialStep(
    screen: TutorialScreen.reviewList,
    targetId: 'review.card',
    title: 'ونڈو کی پڑتال',
    body:
        'یہ آپ کی محفوظ کی ہوئی ونڈو ہے۔ یہاں آپ ناپ دوبارہ دیکھ سکتے ہیں، '
        'قلم کے نشان سے ناپ درست کر سکتے ہیں، اور ڈبے کے نشان سے ونڈو مٹا بھی '
        'سکتے ہیں۔ آگے بڑھنے سے پہلے ہمیشہ یہاں ایک نظر ڈال لیں۔',
  ),
  TutorialStep(
    screen: TutorialScreen.reviewList,
    targetId: 'review.next',
    title: 'کٹنگ کی طرف',
    body: 'سب ٹھیک ہے تو آگے چلیں — یہ تیر دبائیں۔',
    tapHint: 'آگے والا تیر دبائیں',
    requiresTap: true,
  ),

  // --------------------------------------------------- Length optimization
  TutorialStep(
    screen: TutorialScreen.lengthOptimization,
    title: 'لینتھ آپٹیمائزیشن (وَنڈ لگانا)',
    body:
        'یہ صفحہ وہی کام کرتا ہے جسے کاریگر وَنڈ لگانا کہتے ہیں۔ ایپ خود سوچتی '
        'ہے کہ کون سا ٹکڑا کس لینتھ میں سے کاٹا جائے تاکہ ایلومینیم کم سے کم '
        'ضائع ہو۔ جو کام کاغذ پر گھنٹوں لیتا ہے، وہ یہاں چند لمحوں میں ہو جاتا ہے۔',
  ),
  TutorialStep(
    screen: TutorialScreen.lengthOptimization,
    targetId: 'lo.sectionTabs',
    title: 'سیکشن چنیں',
    body:
        'یہ آپ کی ونڈوز میں لگنے والے سارے سیکشن ہیں۔ ایک وقت میں ایک سیکشن کی '
        'کٹنگ دکھائی جاتی ہے۔ کسی ایک سیکشن پر دبائیں۔',
    tapHint: 'کسی ایک سیکشن پر دبائیں',
    requiresTap: true,
  ),
  TutorialStep(
    screen: TutorialScreen.lengthOptimization,
    targetId: 'lo.groups',
    title: 'گروپ',
    body:
        'گروپ کا مطلب ہے کہ اس سیکشن کے لیے کتنی الگ الگ لینتھیں استعمال ہوئیں۔ '
        'ہر گروپ نیچے اپنے الگ کارڈ میں کھلا ہوا ہے — ایک گروپ یعنی ایک لینتھ '
        'اور اس میں سے نکلنے والے سارے ٹکڑے۔',
  ),
  TutorialStep(
    screen: TutorialScreen.lengthOptimization,
    targetId: 'lo.lengths',
    title: 'لینتھیں',
    body:
        'یہ وہ لینتھیں ہیں جو اس سیکشن کے لیے استعمال ہوئیں، فٹ میں۔ ایپ نے '
        'انہی میں سے کاٹ کر سب سے کم ضیاع والا طریقہ نکالا ہے۔ کون سی لینتھیں '
        'دستیاب ہیں، یہ آپ سیٹنگز سے خود طے کر سکتے ہیں۔',
  ),
  TutorialStep(
    screen: TutorialScreen.lengthOptimization,
    targetId: 'lo.wastage',
    title: 'ویسٹیج',
    body:
        'یہاں لکھا ہے کہ اس لینتھ میں سے کاٹنے کے بعد کتنا ٹکڑا بچ گیا — یعنی '
        'ضیاع۔ جتنا کم ہو اتنا اچھا۔ اگر بچا ہوا ٹکڑا کام آنے کے قابل ہو تو '
        'ساتھ Offcut لکھا آتا ہے۔',
  ),
  TutorialStep(
    screen: TutorialScreen.lengthOptimization,
    targetId: 'lo.cutsTable',
    title: 'کٹ کیا ہوتے ہیں',
    body:
        'کٹ وہ ٹکڑا ہے جو کاریگر نے آری سے کاٹنا ہے۔ اس جدول کے خانے یہ ہیں: '
        'WinSize یعنی ونڈو کا ناپ، Window یعنی ونڈو کا نام، No. یعنی ونڈو کا '
        'نمبر، Dimension یعنی ونڈو میں اس ٹکڑے کی جگہ، اور Cuts یعنی اس ٹکڑے '
        'کی اصل لمبائی جو کاٹنی ہے۔ کوئی سطر دبا دیں تو وہ نشان زدہ ہو جاتی ہے '
        '— کاٹتے وقت یاد رہتا ہے کہ کہاں تک پہنچے۔',
  ),
  TutorialStep(
    screen: TutorialScreen.lengthOptimization,
    targetId: 'lo.pdf',
    title: 'کٹنگ کی PDF',
    body:
        'یہ پوری کٹنگ لسٹ کی PDF بناتا ہے تاکہ آپ اسے کاریگر کو بھیج سکیں یا '
        'چھپوا لیں۔ ابھی دبا کر دیکھیں۔',
    tapHint: 'PDF دبائیں',
    requiresTap: true,
  ),
  TutorialStep(
    screen: TutorialScreen.lengthOptimization,
    targetId: 'lo.recalculate',
    title: 'دوبارہ حساب',
    body:
        'اب سب سے کام کی چیز۔ Recalc دبائیں — یہاں سے آپ اپنی شرطوں پر حساب '
        'کروا سکتے ہیں۔',
    tapHint: 'Recalc دبائیں',
    requiresTap: true,
  ),

  // ------------------------------------------------------- Recalculation
  TutorialStep(
    screen: TutorialScreen.sectionRecalculation,
    targetId: 'recalc.header',
    title: 'اپنی شرط پر حساب',
    body:
        'اس صفحے کا مقصد یہ ہے کہ حساب آپ کی مرضی سے ہو، ایپ کی مرضی سے نہیں۔ '
        'گودام میں جو لینتھیں واقعی پڑی ہیں، بس وہی ایپ کو بتا دیں — پھر ایپ '
        'انہی میں سے کٹنگ نکالے گی۔',
  ),
  TutorialStep(
    screen: TutorialScreen.sectionRecalculation,
    targetId: 'recalc.lengthRow',
    title: 'اجازت دی گئی لینتھ',
    body:
        'بائیں طرف لینتھ لکھی ہے — فٹ میں — اور دائیں طرف اس کی تعداد۔ یہ سطر '
        'کہہ رہی ہے: "اتنے فٹ کی اتنی لینتھیں میرے پاس ہیں۔"',
  ),
  TutorialStep(
    screen: TutorialScreen.sectionRecalculation,
    targetId: 'recalc.quantity',
    title: 'تعداد لکھیں',
    body:
        'یہاں لکھیں کہ اس لینتھ کی کتنی لاٹھیں آپ کے پاس ہیں۔ خالی چھوڑ دیں تو '
        'ایپ سمجھے گی کہ جتنی چاہیے اتنی موجود ہیں۔ اور اگر کوئی لینتھ ختم ہو '
        'چکی ہے تو 0 لکھ دیں — ایپ اسے استعمال ہی نہیں کرے گی۔ ابھی کوئی تعداد '
        'لکھ کر دیکھیں۔',
    tapHint: 'تعداد لکھیں',
  ),
  TutorialStep(
    screen: TutorialScreen.sectionRecalculation,
    targetId: 'recalc.extra',
    title: 'کوئی اور لینتھ',
    body:
        'اگر آپ کے پاس کوئی ایسی لینتھ ہے جو اوپر کی فہرست میں نہیں، تو یہاں '
        'لکھ دیں — لمبائی فٹ میں اور ساتھ اس کی تعداد۔ خیال رکھیں: یہ خانہ فٹ '
        'مانگتا ہے، انچ نہیں۔',
  ),
  TutorialStep(
    screen: TutorialScreen.sectionRecalculation,
    targetId: 'recalc.optimize',
    title: 'حساب چلائیں',
    body:
        'شرطیں لکھی جا چکیں۔ اب Optimize Section دبائیں — ایپ انہی لینتھوں میں '
        'سے نئی کٹنگ نکال دے گی۔',
    tapHint: 'Optimize Section دبائیں',
    requiresTap: true,
  ),
  TutorialStep(
    screen: TutorialScreen.sectionRecalculation,
    targetId: 'recalc.result',
    title: 'نیا نتیجہ',
    body:
        'یہ رہا نیا نتیجہ — آپ کی اپنی لینتھوں کے حساب سے۔ پسند آ جائے تو '
        'پیچھے والا تیر دبا کر واپس آ جائیں، ورنہ تعداد بدل کر دوبارہ چلا لیں۔',
    tapHint: 'پیچھے جا کر واپس آئیں',
  ),
  TutorialStep(
    screen: TutorialScreen.lengthOptimization,
    targetId: 'lo.next',
    title: 'مال کی طرف',
    body: 'کٹنگ مکمل ہو گئی۔ اب چلتے ہیں مال اور ریٹ کی طرف — یہ تیر دبائیں۔',
    tapHint: 'آگے والا تیر دبائیں',
    requiresTap: true,
  ),

  // Gauge and colour used to be a screen of their own, asked once for a whole
  // project. They now sit on the size-input screen and belong to each window,
  // so the teaching moved there with them.

  // -------------------------------------------------------- Rate setting
  TutorialStep(
    screen: TutorialScreen.rateSetting,
    targetId: 'rate.section',
    title: 'سیکشن کا نام',
    body:
        'یہ اس کارڈ کے سیکشن کا نام ہے۔ آپ کی ونڈوز میں جتنے سیکشن لگے ہیں، '
        'ہر ایک کا اپنا کارڈ یہاں موجود ہے۔',
  ),
  TutorialStep(
    screen: TutorialScreen.rateSetting,
    targetId: 'rate.totalFt',
    title: 'کل فٹ',
    body:
        'یہ اس سیکشن کا کل مال ہے — فٹ میں۔ یعنی آپ کی ساری ونڈوز ملا کر اس '
        'سیکشن کے اتنے فٹ لگیں گے۔ یہی عدد ریٹ سے ضرب کھا کر قیمت بناتا ہے۔',
  ),
  TutorialStep(
    screen: TutorialScreen.rateSetting,
    targetId: 'rate.value',
    title: 'ریٹ',
    body:
        'یہ اس سیکشن کا فی فٹ ریٹ ہے۔ آپ اسے یہیں بدل سکتے ہیں — یہ تبدیلی '
        'صرف اسی پروجیکٹ پر لگے گی۔ اور اگر ہمیشہ کے لیے بدلنا ہو تو سیٹنگز '
        'میں "ریٹس" سے بدلیں۔',
  ),
  TutorialStep(
    screen: TutorialScreen.rateSetting,
    targetId: 'rate.next',
    title: 'مال کا خلاصہ',
    body: 'ریٹ ٹھیک ہیں تو آگے چلیں۔',
    tapHint: 'آگے والا تیر دبائیں',
    requiresTap: true,
  ),

  // -------------------------------------------------------- Material table
  TutorialStep(
    screen: TutorialScreen.materialTable,
    targetId: 'table.summary',
    title: 'مال کا خلاصہ',
    body:
        'یہ آپ کی خریداری کی فہرست ہے۔ Section یعنی سیکشن کا نام، Length یعنی '
        'کون سی لینتھ، Quantity یعنی اس لینتھ کی کتنی لاٹھیں چاہئیں، Total ft '
        'یعنی کل فٹ، Rates یعنی فی فٹ ریٹ، اور Total Rates یعنی اس سیکشن کی کل '
        'قیمت۔ یہی کاغذ لے کر آپ مارکیٹ جا سکتے ہیں۔',
  ),
  TutorialStep(
    screen: TutorialScreen.materialTable,
    targetId: 'table.next',
    title: 'بل کی طرف',
    body:
        'ایلومینیم کا حساب مکمل۔ اب بل بنائیں گے — جس میں شیشہ، لیبر اور '
        'ہارڈویئر بھی شامل ہو گا۔',
    tapHint: 'آگے والا تیر دبائیں',
    requiresTap: true,
  ),

  // ---------------------------------------------------------- Bill inputs
  TutorialStep(
    screen: TutorialScreen.billInputs,
    targetId: 'bill.glassRate',
    title: 'شیشے کا ریٹ',
    body:
        'شیشے کا ریٹ فی مربع فٹ لکھیں۔ ایپ آپ کی ساری ونڈوز کا رقبہ خود نکال '
        'کر اس ریٹ سے ضرب دے دے گی۔ ابھی ریٹ لکھ کر دیکھیں۔',
    tapHint: 'ریٹ لکھیں',
  ),
  TutorialStep(
    screen: TutorialScreen.billInputs,
    targetId: 'bill.laborRate',
    title: 'لیبر کا ریٹ',
    body:
        'لیبر بھی فی مربع فٹ لکھیں — یعنی ایک مربع فٹ ونڈو بنانے کی اجرت۔ '
        'ابھی لکھ کر دیکھیں۔',
    tapHint: 'ریٹ لکھیں',
  ),
  TutorialStep(
    screen: TutorialScreen.billInputs,
    targetId: 'bill.hardwareRate',
    title: 'ہارڈویئر کا ریٹ',
    body:
        'ہارڈویئر کا حساب فٹ سے نہیں، ونڈو سے ہوتا ہے۔ یعنی ایک ونڈو میں '
        'لگنے والے پہیے، لاک اور پیچ کا کل خرچ لکھیں۔ ابھی لکھ کر دیکھیں۔',
    tapHint: 'ریٹ لکھیں',
  ),
  TutorialStep(
    screen: TutorialScreen.billInputs,
    targetId: 'bill.discount',
    title: 'ڈسکاؤنٹ',
    body:
        'یہ ڈسکاؤنٹ صرف ایلومینیم پر لگتا ہے — شیشے، لیبر یا ہارڈویئر پر نہیں۔ '
        'فیصد میں لکھیں، جیسے 5۔ ابھی لکھ کر دیکھیں۔',
    tapHint: 'فیصد لکھیں',
  ),
  TutorialStep(
    screen: TutorialScreen.billInputs,
    targetId: 'bill.extraCharges',
    title: 'اضافی خرچ',
    body:
        'یہاں وہ خرچے لکھیں جو کسی اور خانے میں نہیں آتے — مثلاً ٹرانسپورٹ کا '
        'کرایہ، سیلیکون کا خرچ، یا مزدوروں کی آمد و رفت۔ یہ رقم سیدھی بل میں '
        'جڑ جائے گی۔',
    tapHint: 'رقم لکھیں',
  ),
  TutorialStep(
    screen: TutorialScreen.billInputs,
    targetId: 'bill.advance',
    title: 'بیعانہ',
    body:
        'گاہک نے جو رقم پہلے دے دی ہے وہ یہاں لکھیں۔ یہ کل رقم میں سے منہا ہو '
        'کر بقایا نکالے گی۔',
    tapHint: 'رقم لکھیں',
  ),
  TutorialStep(
    screen: TutorialScreen.billInputs,
    targetId: 'bill.glassColor',
    title: 'شیشے کا رنگ',
    body:
        'شیشے کا رنگ لکھیں — جیسے کلیئر، براؤن، یا ریفلیکٹو۔ یہ بل پر چھپے گا '
        'تاکہ گاہک کو معلوم رہے کہ کون سا شیشہ لگا ہے۔',
    tapHint: 'رنگ لکھیں',
  ),
  TutorialStep(
    screen: TutorialScreen.billInputs,
    targetId: 'bill.company',
    title: 'ایلومینیم کمپنی',
    body:
        'جس کمپنی کا ایلومینیم آپ لگا رہے ہیں اس کا نام لکھیں۔ یہ بھی بل پر '
        'چھپتا ہے — گاہک کے اعتماد کے لیے۔',
    tapHint: 'کمپنی کا نام لکھیں',
  ),
  TutorialStep(
    screen: TutorialScreen.billInputs,
    targetId: 'bill.customer',
    title: 'گاہک کا نام',
    body: 'گاہک کا نام لکھیں۔ یہ بل کے اوپر چھپے گا۔',
    tapHint: 'نام لکھیں',
  ),
  TutorialStep(
    screen: TutorialScreen.billInputs,
    targetId: 'bill.address',
    title: 'پتہ',
    body: 'گاہک کا پتہ لکھیں — بل اور اپنے ریکارڈ کے لیے۔',
    tapHint: 'پتہ لکھیں',
  ),
  TutorialStep(
    screen: TutorialScreen.billInputs,
    targetId: 'bill.phone',
    title: 'فون نمبر',
    body: 'گاہک کا فون نمبر لکھیں تاکہ بعد میں رابطہ آسان رہے۔',
    tapHint: 'نمبر لکھیں',
  ),
  TutorialStep(
    screen: TutorialScreen.billInputs,
    targetId: 'bill.next',
    title: 'بل بنائیں',
    body: 'سب کچھ لکھا جا چکا۔ اب بل بنتا ہے۔',
    tapHint: 'آگے والا تیر دبائیں',
    requiresTap: true,
  ),

  // ----------------------------------------------------------- Actual bill
  TutorialStep(
    screen: TutorialScreen.actualBill,
    targetId: 'bill.grandTotal',
    title: 'گرینڈ ٹوٹل',
    body:
        'Grand Total کا مطلب ہے کل رقم — یعنی ایلومینیم، شیشہ، لیبر، ہارڈویئر '
        'اور اضافی خرچ سب جوڑ کر، اور ڈسکاؤنٹ منہا کر کے جو بنتی ہے۔ یہی وہ '
        'رقم ہے جو گاہک کو ادا کرنی ہے۔',
  ),
  TutorialStep(
    screen: TutorialScreen.actualBill,
    targetId: 'bill.remainingDue',
    title: 'بقایا',
    body:
        'Remaining Due یعنی بقایا۔ کل رقم میں سے گاہک کا دیا ہوا بیعانہ منہا '
        'کرنے کے بعد جو باقی بچتا ہے، وہ یہاں لکھا ہے۔',
  ),
  TutorialStep(
    screen: TutorialScreen.actualBill,
    targetId: 'bill.inputDetails',
    title: 'اِن پُٹ ڈیٹیلز',
    body:
        'Input Details یعنی وہ ساری تفصیل جو آپ نے خود لکھی تھی — گیج، '
        'ایلومینیم کا رنگ، شیشے کا رنگ، کمپنی، اور گاہک کا نام، فون اور پتہ۔ '
        'یہاں ایک نظر ڈال کر تسلی کر لیں کہ کچھ غلط تو نہیں لکھا گیا۔',
  ),
  TutorialStep(
    screen: TutorialScreen.actualBill,
    targetId: 'bill.companyCard',
    title: 'کمپنی / ورکشاپ',
    body:
        'Company / Workshop یعنی آپ کی اپنی معلومات — ٹھیکیدار کا نام، ورکشاپ '
        'کا نام، فون اور پتہ۔ یہ بل کے اوپر آپ کی پہچان بن کر چھپتی ہے۔ اسے ایک '
        'بار سیٹنگز میں لکھ دیں، پھر ہر بل پر خود آ جائے گی۔',
  ),
  TutorialStep(
    screen: TutorialScreen.actualBill,
    targetId: 'bill.ratesUsed',
    title: 'استعمال شدہ ریٹ',
    body:
        'Rates Used یعنی وہ ریٹ جن پر یہ بل بنا ہے — شیشہ فی مربع فٹ، لیبر فی '
        'مربع فٹ، ہارڈویئر فی ونڈو، اور ایلومینیم پر ڈسکاؤنٹ کا فیصد۔ گاہک '
        'پوچھے کہ حساب کیسے لگا، تو یہی جواب ہے۔',
  ),
  TutorialStep(
    screen: TutorialScreen.actualBill,
    targetId: 'bill.costBreakdown',
    title: 'خرچ کی تفصیل',
    body:
        'Cost Breakdown یعنی رقم کی پوری تقسیم — شیشے کا خرچ، لیبر کا خرچ، '
        'ہارڈویئر کا خرچ، ڈسکاؤنٹ سے پہلے اور بعد کی ایلومینیم کی رقم، اضافی '
        'خرچ، بیعانہ، اور آخر میں کل رقم اور بقایا۔ ہر عدد یہاں کھلا ہوا ہے، '
        'کچھ چھپا ہوا نہیں۔',
  ),
  TutorialStep(
    screen: TutorialScreen.actualBill,
    targetId: 'bill.downloadPdf',
    title: 'بل ڈاؤن لوڈ کریں',
    body: 'اب بل کی PDF بنائیں۔ یہ بٹن دبائیں۔',
    tapHint: 'Download PDF دبائیں',
    requiresTap: true,
  ),
  TutorialStep(
    screen: TutorialScreen.actualBill,
    title: 'PDF کہاں گئی؟',
    body:
        'بل آپ کے فون میں محفوظ ہو گیا ہے۔ اسے دیکھنے کے لیے فون کے فولڈر '
        'کھولیں اور Downloads والے فولڈر میں جائیں — بل وہیں پڑا ملے گا۔ وہاں '
        'سے آپ اسے واٹس ایپ پر بھیج سکتے ہیں یا چھپوا سکتے ہیں۔',
  ),
  TutorialStep(
    screen: TutorialScreen.actualBill,
    targetId: 'bill.home',
    title: 'ایسٹیمیشن مکمل',
    body:
        'بس، ایسٹیمیشن کا سفر یہیں ختم ہوتا ہے — ونڈو کے ناپ سے لے کر گاہک کے '
        'بل تک۔ Home دبائیں اور اپنا اصل کام شروع کریں۔ یہ رہنمائی آپ جب چاہیں '
        'ہوم پیج کے بٹن سے دوبارہ چلا سکتے ہیں۔',
    tapHint: 'Home دبائیں',
    requiresTap: true,
  ),
];
