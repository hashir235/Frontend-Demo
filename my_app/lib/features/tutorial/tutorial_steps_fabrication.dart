import 'tutorial_step.dart';

/// The guided tour of the Fabrication flow, in Urdu.
///
/// Fabrication walks through the same screens as Estimation but the work is
/// different: here the numbers are the ones a cutter actually cuts to, so the
/// wording talks about the saw, the glass and the shop floor rather than about
/// quoting a customer. There is no bill at the end -- the flow finishes at the
/// material table and the glass report.
///
/// Kept in its own list, with its own button and its own "seen" flag, so that
/// someone who only does fabrication is never walked through billing.
const List<TutorialStep> fabricationTutorialSteps = <TutorialStep>[
  // ---------------------------------------------------------------- Home
  TutorialStep(
    screen: TutorialScreen.home,
    title: 'فیبریکیشن کی رہنمائی',
    body:
        'یہ رہنمائی فیبریکیشن کے لیے ہے — یعنی جب کام کا آرڈر مل چکا ہو اور اب '
        'اصل کٹنگ کرنی ہو۔ ہم مل کر ایک پورا فیبریکیشن پروجیکٹ بنائیں گے۔ کسی '
        'بھی وقت "چھوڑ دیں" دبا کر باہر نکل سکتے ہیں۔',
  ),
  TutorialStep(
    screen: TutorialScreen.home,
    targetId: 'home.fabrication',
    title: 'فیبریکیشن',
    body:
        'ایسٹیمیشن اور فیبریکیشن میں فرق یہ ہے: ایسٹیمیشن گاہک کو قیمت بتانے '
        'کے لیے ہے، اور فیبریکیشن اصل کٹنگ کے لیے۔ یہاں کے ناپ وہی ہیں جن پر '
        'آری چلے گی، اور ساتھ شیشے کی رپورٹ بھی ملتی ہے۔ اسے دبائیں۔',
    tapHint: 'فیبریکیشن پر دبائیں',
    requiresTap: true,
  ),

  // ------------------------------------------------------ Fabrication menu
  TutorialStep(
    screen: TutorialScreen.fabricationMenu,
    targetId: 'fab.createProject',
    title: 'نیا پروجیکٹ',
    body:
        'یہاں سے نیا فیبریکیشن پروجیکٹ بنتا ہے۔ نام اور جگہ لکھیں — بعد میں '
        'اسی نام سے کام دوبارہ کھلے گا۔ پرانے پروجیکٹ نیچے فہرست میں ملیں گے۔',
    tapHint: 'نیا پروجیکٹ بنائیں',
    requiresTap: true,
  ),

  // ------------------------------------------------------- Window library
  TutorialStep(
    screen: TutorialScreen.windowLibrary,
    targetId: 'library.sliding',
    title: 'ونڈو چنیں',
    body:
        'وہ ونڈو چنیں جو آپ نے بنانی ہے۔ سیکھنے کے لیے ہم سلائیڈنگ ونڈو لیں '
        'گے۔ اسے دبائیں۔',
    tapHint: 'سلائیڈنگ ونڈو پر دبائیں',
    requiresTap: true,
  ),

  // --------------------------------------------------------- Window input
  TutorialStep(
    screen: TutorialScreen.windowInput,
    targetId: 'input.winNo',
    title: 'ونڈو نمبر',
    body:
        'فیبریکیشن میں یہ نمبر سب سے کام کا ہے۔ کٹنگ لسٹ میں ہر ٹکڑے کے سامنے '
        'یہی نمبر لکھا آتا ہے، جس سے کاریگر کو فوراً پتہ چلتا ہے کہ یہ ٹکڑا '
        'کون سی ونڈو کا ہے۔',
  ),
  TutorialStep(
    screen: TutorialScreen.windowInput,
    targetId: 'input.collarCards',
    title: 'کالر کی قسم',
    body:
        'انگلی سے دائیں بائیں سرکا کر وہی کالر سامنے لائیں جو آپ کی ونڈو کا '
        'ہے — دو، تین یا چار۔ کٹنگ کے ناپ اسی سے بدلتے ہیں، اس لیے یہاں غلطی '
        'مہنگی پڑتی ہے۔',
    tapHint: 'کارڈ کو دائیں سرکا کر دیکھیں',
  ),
  TutorialStep(
    screen: TutorialScreen.windowInput,
    targetId: 'input.unit',
    title: 'یونٹ',
    body:
        'ناپ لکھنے سے پہلے یونٹ دیکھ لیں — فٹ، انچ یا سینٹی میٹر۔ فیبریکیشن '
        'میں غلط یونٹ کا مطلب ہے غلط کٹنگ اور ضائع شدہ ایلومینیم۔',
  ),
  TutorialStep(
    screen: TutorialScreen.windowInput,
    targetId: 'input.sizes',
    title: 'ونڈو کا ناپ',
    body:
        'یہاں اصل ناپ لکھیں — وہی جو موقع پر ناپا گیا ہے۔ ایپ خود ہر سیکشن کی '
        'کٹنگ مارجن گھٹا کر ٹکڑوں کی لمبائی نکالے گی۔ ابھی ناپ لکھ کر دیکھیں۔',
    tapHint: 'اونچائی اور چوڑائی لکھیں',
  ),
  TutorialStep(
    screen: TutorialScreen.windowInput,
    targetId: 'input.wheel',
    title: 'انچ اور سُتر کا پہیہ',
    body:
        'پورے فٹ کے ساتھ بچنے والے انچ یا سُتر اس پہیے سے چنیں — بالکل اِنچی '
        'ٹیپ کی طرح۔ ہاتھ سے لکھنا آسان لگے تو سیٹنگز سے اس پہیے کی جگہ لکھنے '
        'والا خانہ لگا لیں۔',
  ),
  TutorialStep(
    screen: TutorialScreen.windowInput,
    targetId: 'input.description',
    title: 'تفصیل',
    body:
        'یہاں لکھیں کہ یہ ونڈو کہاں لگنی ہے — جیسے "باتھ روم"۔ یہی تفصیل کٹنگ '
        'لسٹ پر چھپتی ہے، اور شاپ فلور پر ٹکڑے آپس میں نہیں گڈمڈ ہوتے۔',
  ),
  TutorialStep(
    screen: TutorialScreen.windowInput,
    targetId: 'input.quantity',
    title: 'کتنی ونڈوز',
    body:
        'اسی ناپ کی ایک سے زیادہ ونڈوز ہیں تو تعداد لکھ دیں۔ ایپ خود اتنی '
        'ونڈوز بنا دے گی اور کٹنگ بھی اسی حساب سے نکالے گی۔',
    tapHint: 'تعداد لکھیں',
  ),
  TutorialStep(
    screen: TutorialScreen.windowInput,
    targetId: 'input.save',
    title: 'محفوظ کریں',
    body: 'ناپ مکمل۔ اب اسے محفوظ کریں۔',
    tapHint: 'محفوظ کریں دبائیں',
    requiresTap: true,
  ),
  TutorialStep(
    screen: TutorialScreen.windowInput,
    targetId: 'input.sectionsButton',
    title: 'سیکشنز',
    body:
        'یہ بٹن ونڈو کے سیکشن کھولتا ہے، اور وہ چیزیں جو ایک بار طے کرنی ہوتی '
        'ہیں — جیسے کالر کی موٹائی اور جالی۔ اسے دبائیں۔',
    tapHint: 'سیکشنز پر دبائیں',
    requiresTap: true,
  ),
  TutorialStep(
    screen: TutorialScreen.windowInput,
    targetId: 'input.sidebarSections',
    title: 'سیکشن کے بٹن',
    body:
        'ان بٹنوں کا مقصد یہ ہے کہ آپ کو دکھایا جائے کہ جو ونڈو آپ نے چنی ہے، '
        'اس کا یہ سیکشن کہاں لگ رہا ہے۔ کسی ایک پر دبائیں — تصویر میں وہی حصہ '
        'نمایاں ہو جائے گا۔ کٹنگ سے پہلے یہ دیکھ لینا اچھی عادت ہے۔',
    tapHint: 'کسی ایک سیکشن پر دبائیں',
    requiresTap: true,
  ),
  TutorialStep(
    screen: TutorialScreen.windowInput,
    title: 'پینل بند کریں',
    body:
        'پینل سے باہر آنے کے لیے اس کے پہلو میں، اصل صفحے پر کہیں بھی انگلی '
        'رکھیں — پینل خود بند ہو جائے گا۔',
    tapHint: 'صفحے کے کھلے حصے پر دبائیں',
  ),
  TutorialStep(
    screen: TutorialScreen.windowInput,
    targetId: 'input.next',
    title: 'اگلا قدم',
    body: 'مزید ونڈوز ڈالنی ہوں تو یہیں سے ڈالتے رہیں۔ ابھی آگے چلتے ہیں۔',
    tapHint: 'آگے والا تیر دبائیں',
    requiresTap: true,
  ),

  // ----------------------------------------------------------- Review list
  TutorialStep(
    screen: TutorialScreen.reviewList,
    targetId: 'review.card',
    title: 'کٹنگ سے پہلے پڑتال',
    body:
        'یہ آپ کی محفوظ ونڈو ہے۔ قلم سے ناپ درست کریں، ڈبے سے ونڈو مٹائیں۔ '
        'فیبریکیشن میں یہ آخری موقع ہے غلطی پکڑنے کا — آری چلنے کے بعد ناپ '
        'واپس نہیں آتا۔',
  ),
  TutorialStep(
    screen: TutorialScreen.reviewList,
    targetId: 'review.next',
    title: 'کٹنگ کی طرف',
    body: 'ناپ ٹھیک ہیں تو آگے چلیں۔',
    tapHint: 'آگے والا تیر دبائیں',
    requiresTap: true,
  ),

  // --------------------------------------------------- Length optimization
  TutorialStep(
    screen: TutorialScreen.lengthOptimization,
    title: 'لینتھ آپٹیمائزیشن (وَنڈ لگانا)',
    body:
        'یہ وہی کام ہے جسے کاریگر وَنڈ لگانا کہتے ہیں۔ ایپ خود طے کرتی ہے کہ '
        'کون سا ٹکڑا کس لاٹھی میں سے کاٹا جائے تاکہ ایلومینیم کم سے کم ضائع ہو۔ '
        'یہی صفحہ آپ کی اصل کٹنگ لسٹ ہے۔',
  ),
  TutorialStep(
    screen: TutorialScreen.lengthOptimization,
    targetId: 'lo.sectionTabs',
    title: 'سیکشن چنیں',
    body:
        'ایک وقت میں ایک سیکشن کی کٹنگ دکھائی جاتی ہے۔ عام طور پر کاریگر ایک '
        'سیکشن پورا کاٹ کر اگلے پر جاتا ہے۔ کسی ایک سیکشن پر دبائیں۔',
    tapHint: 'کسی ایک سیکشن پر دبائیں',
    requiresTap: true,
  ),
  TutorialStep(
    screen: TutorialScreen.lengthOptimization,
    targetId: 'lo.groups',
    title: 'گروپ',
    body:
        'گروپ یعنی اس سیکشن کے لیے کتنی الگ الگ لینتھیں لگیں۔ ہر گروپ ایک '
        'لاٹھی ہے، اور اس کے کارڈ میں وہ سارے ٹکڑے ہیں جو اسی لاٹھی سے نکلیں گے۔',
  ),
  TutorialStep(
    screen: TutorialScreen.lengthOptimization,
    targetId: 'lo.lengths',
    title: 'لینتھیں',
    body:
        'یہ وہ لینتھیں ہیں جو استعمال ہوئیں، فٹ میں۔ کون سی لینتھیں دستیاب '
        'ہیں، یہ آپ سیٹنگز سے طے کر سکتے ہیں — اور اگر گودام میں کچھ اور پڑا '
        'ہے تو اگلے صفحے پر بتا سکتے ہیں۔',
  ),
  TutorialStep(
    screen: TutorialScreen.lengthOptimization,
    targetId: 'lo.wastage',
    title: 'ویسٹیج',
    body:
        'یہاں لکھا ہے کہ اس لاٹھی سے کاٹنے کے بعد کتنا حصہ بچ گیا — یعنی ضیاع۔ '
        'اگر بچا ہوا ٹکڑا آگے کام آنے کے قابل ہو تو ساتھ Offcut لکھا آتا ہے، '
        'اسے سنبھال کر رکھیں۔',
  ),
  TutorialStep(
    screen: TutorialScreen.lengthOptimization,
    targetId: 'lo.cutsTable',
    title: 'کٹ کیا ہوتے ہیں',
    body:
        'کٹ وہ ٹکڑا ہے جو آری سے کاٹنا ہے۔ خانے یہ ہیں: WinSize یعنی ونڈو کا '
        'ناپ، Window یعنی ونڈو کا نام، No. یعنی ونڈو کا نمبر، Dimension یعنی '
        'ونڈو میں اس ٹکڑے کی جگہ، اور Cuts یعنی وہ اصل لمبائی جس پر آری چلے '
        'گی۔ ہر کٹا ہوا ٹکڑا اس کی سطر دبا کر نشان زدہ کرتے جائیں — پھر یاد '
        'رہتا ہے کہ کہاں تک پہنچے۔',
  ),
  TutorialStep(
    screen: TutorialScreen.lengthOptimization,
    targetId: 'lo.pdf',
    title: 'کٹنگ کی PDF',
    body:
        'یہ پوری کٹنگ لسٹ کی PDF بناتا ہے۔ اسے چھپوا کر آری کے پاس رکھ لیں یا '
        'کاریگر کو واٹس ایپ کر دیں۔ ابھی دبا کر دیکھیں۔',
    tapHint: 'PDF دبائیں',
    requiresTap: true,
  ),
  TutorialStep(
    screen: TutorialScreen.lengthOptimization,
    targetId: 'lo.recalculate',
    title: 'دوبارہ حساب',
    body:
        'فیبریکیشن میں یہ سب سے کام کا بٹن ہے۔ گودام میں جو لینتھیں واقعی پڑی '
        'ہیں، انہی پر حساب کروانے کے لیے Recalc دبائیں۔',
    tapHint: 'Recalc دبائیں',
    requiresTap: true,
  ),

  // ------------------------------------------------------- Recalculation
  TutorialStep(
    screen: TutorialScreen.sectionRecalculation,
    targetId: 'recalc.header',
    title: 'اپنی شرط پر حساب',
    body:
        'اس صفحے کا مقصد یہ ہے کہ حساب آپ کے گودام کے مطابق ہو۔ ایپ کو بتا دیں '
        'کہ کون سی لینتھ کتنی موجود ہے — پھر کٹنگ انہی میں سے نکلے گی، کسی '
        'ایسی لاٹھی سے نہیں جو آپ کے پاس ہے ہی نہیں۔',
  ),
  TutorialStep(
    screen: TutorialScreen.sectionRecalculation,
    targetId: 'recalc.lengthRow',
    title: 'اجازت دی گئی لینتھ',
    body:
        'بائیں طرف لینتھ فٹ میں، دائیں طرف اس کی تعداد۔ یہ سطر کہہ رہی ہے: '
        '"اتنے فٹ کی اتنی لاٹھیاں میرے پاس ہیں۔"',
  ),
  TutorialStep(
    screen: TutorialScreen.sectionRecalculation,
    targetId: 'recalc.quantity',
    title: 'تعداد لکھیں',
    body:
        'یہاں لکھیں کہ اس لینتھ کی کتنی لاٹھیاں موجود ہیں۔ خالی چھوڑیں تو ایپ '
        'سمجھے گی کہ جتنی چاہئیں اتنی ہیں، اور 0 لکھیں تو وہ لینتھ استعمال ہی '
        'نہیں ہو گی۔ ابھی تعداد لکھ کر دیکھیں۔',
    tapHint: 'تعداد لکھیں',
  ),
  TutorialStep(
    screen: TutorialScreen.sectionRecalculation,
    targetId: 'recalc.extra',
    title: 'کوئی اور لینتھ',
    body:
        'کوئی لینتھ فہرست میں نہیں تو یہاں لکھ دیں — لمبائی فٹ میں اور ساتھ '
        'تعداد۔ خیال رکھیں: یہ خانہ فٹ مانگتا ہے، انچ نہیں۔',
  ),
  TutorialStep(
    screen: TutorialScreen.sectionRecalculation,
    targetId: 'recalc.optimize',
    title: 'حساب چلائیں',
    body:
        'اب Optimize Section دبائیں — ایپ انہی لاٹھیوں میں سے نئی کٹنگ نکال دے گی۔',
    tapHint: 'Optimize Section دبائیں',
    requiresTap: true,
  ),
  TutorialStep(
    screen: TutorialScreen.sectionRecalculation,
    targetId: 'recalc.result',
    title: 'نیا نتیجہ',
    body:
        'یہ رہا نیا نتیجہ — آپ کے اپنے گودام کے حساب سے۔ پسند آ جائے تو پیچھے '
        'والا تیر دبا کر واپس آ جائیں، ورنہ تعداد بدل کر دوبارہ چلا لیں۔',
    tapHint: 'پیچھے جا کر واپس آئیں',
  ),
  TutorialStep(
    screen: TutorialScreen.lengthOptimization,
    targetId: 'lo.next',
    title: 'مال کی طرف',
    body: 'کٹنگ مکمل۔ اب دیکھتے ہیں کہ کتنا مال منگوانا ہے۔',
    tapHint: 'آگے والا تیر دبائیں',
    requiresTap: true,
  ),

  // ---------------------------------------------------- Material selection
  TutorialStep(
    screen: TutorialScreen.materialSelection,
    targetId: 'material.gauge',
    title: 'گیج چنیں',
    body: 'گیج یعنی ایلومینیم کی موٹائی۔ وہی چنیں جو آپ واقعی لگا رہے ہیں۔',
    tapHint: 'کوئی ایک گیج چنیں',
    requiresTap: true,
  ),
  TutorialStep(
    screen: TutorialScreen.materialSelection,
    targetId: 'material.colour',
    title: 'رنگ چنیں',
    body: 'اب ایلومینیم کا رنگ چنیں۔ ہر رنگ کا اپنا ریٹ ہوتا ہے۔',
    tapHint: 'کوئی ایک رنگ چنیں',
    requiresTap: true,
  ),
  TutorialStep(
    screen: TutorialScreen.materialSelection,
    targetId: 'material.next',
    title: 'ریٹ آپ کے اپنے',
    body:
        'ریٹ ہر شہر میں الگ ہوتے ہیں۔ سیٹنگز میں "ریٹس" سے آپ ہر سیکشن، گیج '
        'اور رنگ کا ریٹ اپنے حساب سے رکھ سکتے ہیں۔ ابھی آگے چلیں۔',
    tapHint: 'آگے والا تیر دبائیں',
    requiresTap: true,
  ),

  // -------------------------------------------------------- Rate setting
  TutorialStep(
    screen: TutorialScreen.rateSetting,
    targetId: 'rate.section',
    title: 'سیکشن کا نام',
    body: 'ہر سیکشن کا اپنا کارڈ ہے۔ یہ اس کارڈ کے سیکشن کا نام ہے۔',
  ),
  TutorialStep(
    screen: TutorialScreen.rateSetting,
    targetId: 'rate.totalFt',
    title: 'کل فٹ',
    body:
        'یہ اس سیکشن کا کل مال ہے — فٹ میں۔ یہی عدد بتاتا ہے کہ مارکیٹ سے کتنا '
        'منگوانا ہے۔',
  ),
  TutorialStep(
    screen: TutorialScreen.rateSetting,
    targetId: 'rate.value',
    title: 'ریٹ',
    body:
        'فی فٹ ریٹ۔ یہیں بدلیں تو صرف اسی پروجیکٹ پر لگے گا؛ ہمیشہ کے لیے '
        'بدلنا ہو تو سیٹنگز میں "ریٹس" سے بدلیں۔',
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
        'یہ آپ کی خریداری کی فہرست ہے۔ Section یعنی سیکشن، Length یعنی کون سی '
        'لینتھ، Quantity یعنی اس کی کتنی لاٹھیاں چاہئیں، Total ft یعنی کل فٹ، '
        'Rates یعنی فی فٹ ریٹ، اور Total Rates یعنی کل قیمت۔ یہی کاغذ لے کر '
        'مارکیٹ جائیں۔',
  ),
  TutorialStep(
    screen: TutorialScreen.materialTable,
    targetId: 'table.glassReport',
    title: 'شیشے کی رپورٹ',
    body:
        'فیبریکیشن کی خاص چیز یہی ہے۔ Glass Report دبائیں — ہر ونڈو کے شیشے کا '
        'ناپ الگ الگ نکل آئے گا، اسی حساب سے جیسے شیشے والے کو دینا ہوتا ہے۔ '
        'اس کی PDF بھی بن جاتی ہے۔',
    tapHint: 'Glass Report دبائیں',
    requiresTap: true,
  ),
  TutorialStep(
    screen: TutorialScreen.materialTable,
    title: 'فیبریکیشن مکمل',
    body:
        'بس، فیبریکیشن کا سفر یہیں مکمل ہوتا ہے — ونڈو کے ناپ سے لے کر کٹنگ '
        'لسٹ، مال کی فہرست اور شیشے کی رپورٹ تک۔ یہ رہنمائی آپ جب چاہیں ہوم '
        'پیج کے بٹن سے دوبارہ چلا سکتے ہیں۔',
  ),
];
