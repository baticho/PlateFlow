/// Generated file. Do not edit.
///
/// Original: lib/i18n
/// To regenerate, run: `dart run slang`
///
/// Locales: 2
/// Strings: 484 (242 per locale)
///
/// Built on 2026-11-09 at 16:56 UTC

// coverage:ignore-file
// ignore_for_file: type=lint

import 'package:flutter/widgets.dart';
import 'package:slang/builder/model/node.dart';
import 'package:slang_flutter/slang_flutter.dart';
export 'package:slang_flutter/slang_flutter.dart';

const AppLocale _baseLocale = AppLocale.en;

/// Supported locales, see extension methods below.
///
/// Usage:
/// - LocaleSettings.setLocale(AppLocale.en) // set locale
/// - Locale locale = AppLocale.en.flutterLocale // get flutter locale from enum
/// - if (LocaleSettings.currentLocale == AppLocale.en) // locale check
enum AppLocale with BaseAppLocale<AppLocale, Translations> {
	en(languageCode: 'en', build: Translations.build),
	bg(languageCode: 'bg', build: _StringsBg.build);

	const AppLocale({required this.languageCode, this.scriptCode, this.countryCode, required this.build}); // ignore: unused_element

	@override final String languageCode;
	@override final String? scriptCode;
	@override final String? countryCode;
	@override final TranslationBuilder<AppLocale, Translations> build;

	/// Gets current instance managed by [LocaleSettings].
	Translations get translations => LocaleSettings.instance.translationMap[this]!;
}

/// Method A: Simple
///
/// No rebuild after locale change.
/// Translation happens during initialization of the widget (call of t).
/// Configurable via 'translate_var'.
///
/// Usage:
/// String a = t.someKey.anotherKey;
/// String b = t['someKey.anotherKey']; // Only for edge cases!
Translations get t => LocaleSettings.instance.currentTranslations;

/// Method B: Advanced
///
/// All widgets using this method will trigger a rebuild when locale changes.
/// Use this if you have e.g. a settings page where the user can select the locale during runtime.
///
/// Step 1:
/// wrap your App with
/// TranslationProvider(
/// 	child: MyApp()
/// );
///
/// Step 2:
/// final t = Translations.of(context); // Get t variable.
/// String a = t.someKey.anotherKey; // Use t variable.
/// String b = t['someKey.anotherKey']; // Only for edge cases!
class TranslationProvider extends BaseTranslationProvider<AppLocale, Translations> {
	TranslationProvider({required super.child}) : super(settings: LocaleSettings.instance);

	static InheritedLocaleData<AppLocale, Translations> of(BuildContext context) => InheritedLocaleData.of<AppLocale, Translations>(context);
}

/// Method B shorthand via [BuildContext] extension method.
/// Configurable via 'translate_var'.
///
/// Usage (e.g. in a widget's build method):
/// context.t.someKey.anotherKey
extension BuildContextTranslationsExtension on BuildContext {
	Translations get t => TranslationProvider.of(this).translations;
}

/// Manages all translation instances and the current locale
class LocaleSettings extends BaseFlutterLocaleSettings<AppLocale, Translations> {
	LocaleSettings._() : super(utils: AppLocaleUtils.instance);

	static final instance = LocaleSettings._();

	// static aliases (checkout base methods for documentation)
	static AppLocale get currentLocale => instance.currentLocale;
	static Stream<AppLocale> getLocaleStream() => instance.getLocaleStream();
	static AppLocale setLocale(AppLocale locale, {bool? listenToDeviceLocale = false}) => instance.setLocale(locale, listenToDeviceLocale: listenToDeviceLocale);
	static AppLocale setLocaleRaw(String rawLocale, {bool? listenToDeviceLocale = false}) => instance.setLocaleRaw(rawLocale, listenToDeviceLocale: listenToDeviceLocale);
	static AppLocale useDeviceLocale() => instance.useDeviceLocale();
	@Deprecated('Use [AppLocaleUtils.supportedLocales]') static List<Locale> get supportedLocales => instance.supportedLocales;
	@Deprecated('Use [AppLocaleUtils.supportedLocalesRaw]') static List<String> get supportedLocalesRaw => instance.supportedLocalesRaw;
	static void setPluralResolver({String? language, AppLocale? locale, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver}) => instance.setPluralResolver(
		language: language,
		locale: locale,
		cardinalResolver: cardinalResolver,
		ordinalResolver: ordinalResolver,
	);
}

/// Provides utility functions without any side effects.
class AppLocaleUtils extends BaseAppLocaleUtils<AppLocale, Translations> {
	AppLocaleUtils._() : super(baseLocale: _baseLocale, locales: AppLocale.values);

	static final instance = AppLocaleUtils._();

	// static aliases (checkout base methods for documentation)
	static AppLocale parse(String rawLocale) => instance.parse(rawLocale);
	static AppLocale parseLocaleParts({required String languageCode, String? scriptCode, String? countryCode}) => instance.parseLocaleParts(languageCode: languageCode, scriptCode: scriptCode, countryCode: countryCode);
	static AppLocale findDeviceLocale() => instance.findDeviceLocale();
	static List<Locale> get supportedLocales => instance.supportedLocales;
	static List<String> get supportedLocalesRaw => instance.supportedLocalesRaw;
}

// translations

// Path: <root>
class Translations implements BaseTranslations<AppLocale, Translations> {
	/// Returns the current translations of the given [context].
	///
	/// Usage:
	/// final t = Translations.of(context);
	static Translations of(BuildContext context) => InheritedLocaleData.of<AppLocale, Translations>(context).translations;

	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	Translations.build({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = TranslationMetadata(
		    locale: AppLocale.en,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ) {
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <en>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	dynamic operator[](String key) => $meta.getTranslation(key);

	late final Translations _root = this; // ignore: unused_field

	// Translations
	late final _StringsAppEn app = _StringsAppEn._(_root);
	late final _StringsNavEn nav = _StringsNavEn._(_root);
	late final _StringsHomeEn home = _StringsHomeEn._(_root);
	late final _StringsRecipeEn recipe = _StringsRecipeEn._(_root);
	late final _StringsExploreEn explore = _StringsExploreEn._(_root);
	late final _StringsMealPlanEn mealPlan = _StringsMealPlanEn._(_root);
	late final _StringsShoppingListEn shoppingList = _StringsShoppingListEn._(_root);
	late final _StringsCookingEn cooking = _StringsCookingEn._(_root);
	late final _StringsFavoritesEn favorites = _StringsFavoritesEn._(_root);
	late final _StringsProfileEn profile = _StringsProfileEn._(_root);
	late final _StringsUnitsEn units = _StringsUnitsEn._(_root);
	late final _StringsSubscriptionEn subscription = _StringsSubscriptionEn._(_root);
	late final _StringsAuthEn auth = _StringsAuthEn._(_root);
	late final _StringsCommonEn common = _StringsCommonEn._(_root);
	late final _StringsFamilyEn family = _StringsFamilyEn._(_root);
	late final _StringsUpdateEn update = _StringsUpdateEn._(_root);
}

// Path: app
class _StringsAppEn {
	_StringsAppEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get name => 'PlateFlow';
}

// Path: nav
class _StringsNavEn {
	_StringsNavEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get home => 'Home';
	String get explore => 'Explore';
	String get mealPlan => 'Meal Plan';
	String get shopping => 'Shopping';
	String get profile => 'Profile';
}

// Path: home
class _StringsHomeEn {
	_StringsHomeEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get weeklyTitle => 'This Week\'s Picks';
	String get trending => 'Trending Now';
	String get quickMeals => 'Quick Meals';
	String get favorites => 'Your favourites';
	String get seeAll => 'See all';
}

// Path: recipe
class _StringsRecipeEn {
	_StringsRecipeEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get ingredients => 'Ingredients';
	String get steps => 'Steps';
	String servings({required Object count}) => '${count} serving(s)';
	String prepTime({required Object minutes}) => 'Prep: ${minutes} min';
	String cookTime({required Object minutes}) => 'Cook: ${minutes} min';
	String totalTime({required Object minutes}) => '${minutes} min';
	late final _StringsRecipeDifficultyEn difficulty = _StringsRecipeDifficultyEn._(_root);
	String get portions => 'Portions';
	String get description => 'Description';
	String get noSteps => 'No steps available.';
	String get addToMealPlan => 'Add to Meal Plan';
	String get addToShoppingList => 'Add to Shopping List';
	String get startCooking => 'Start Cooking';
	late final _StringsRecipeNutritionEn nutrition = _StringsRecipeNutritionEn._(_root);
	String get share => 'Share';
	String get sharedFrom => 'Shared from PlateFlow';
}

// Path: explore
class _StringsExploreEn {
	_StringsExploreEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get searchHint => 'Search recipes, ingredients...';
	String get categories => 'Categories';
	String get cuisines => 'Cuisines';
	String get filters => 'Filters';
	String get filterByTime => 'Max Cook Time';
	String get filterByDifficulty => 'Difficulty';
	String get searchByIngredients => 'Search by Ingredients';
	String get searchByIngredientsDesc => 'Find recipes using what\'s in your fridge';
	String get ingredientHint => 'Type an ingredient...';
	String get findRecipes => 'Find Recipes';
	String get premiumOnly => 'Premium Feature';
	String get premiumOnlyDesc => 'Upgrade to Premium to search recipes by ingredients';
	String get randomMeal => 'Random meal';
}

// Path: mealPlan
class _StringsMealPlanEn {
	_StringsMealPlanEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get title => 'Meal Plan';
	String get generateShoppingList => 'Generate Shopping List';
	String get addMeal => 'Add Meal';
	late final _StringsMealPlanDaysEn days = _StringsMealPlanDaysEn._(_root);
	late final _StringsMealPlanMealTypesEn mealTypes = _StringsMealPlanMealTypesEn._(_root);
	String get viewPlan => 'View Plan';
	String get removeTitle => 'Remove recipe';
	String removeConfirm({required Object title}) => 'Remove "${title}" from your meal plan?';
	String get cook => 'Cook';
	String get cooked => 'Cooked';
	String get randomMeal => 'Random';
	String get randomDay => 'Surprise me for the day';
	String get noRandom => 'No recipes in this category';
	String get randomServings => 'How many servings?';
	String get randomAdd => 'Add';
	String get move => 'Move';
	String get moveTitle => 'Move to which day?';
	String moved({required Object date}) => 'Moved: ${date}';
	String get reroll => 'Another recipe';
	String get rerollBack => 'Bring back the previous one';
	String rerolled({required Object title}) => 'Swapped for “${title}”';
	String get undo => 'Undo';
	String get rerollBoughtTitle => 'Products already bought';
	String rerollBoughtBody({required Object title}) => 'Some products for “${title}” were already bought. Swap it for another recipe?';
	String get rerollSwap => 'Swap';
	String get shiftDays => 'Shift days';
	String get shiftTitle => 'Shift the plan';
	String shiftBody({required Object date}) => 'All uncooked recipes from ${date} on will move forward. Their products in the cart move with them.';
	String get shiftBy => 'By how many days?';
	String get shiftDo => 'Shift';
	String shifted({required Object count}) => 'Recipes shifted: ${count}';
	String get shiftNothing => 'No recipes to shift';
}

// Path: shoppingList
class _StringsShoppingListEn {
	_StringsShoppingListEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get title => 'Shopping List';
	String get empty => 'No items yet. Generate from your meal plan!';
	String get clearChecked => 'Clear Checked';
	String itemsCount({required Object checked, required Object total}) => '${checked} / ${total} items';
	late final _StringsShoppingListCategoriesEn categories = _StringsShoppingListCategoriesEn._(_root);
	late final _StringsShoppingListDetailsEn details = _StringsShoppingListDetailsEn._(_root);
	String get viewAll => 'All items';
	String get byDay => 'By day';
	String get noDay => 'No day';
	String get today => 'Today';
}

// Path: cooking
class _StringsCookingEn {
	_StringsCookingEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String stepOf({required Object current, required Object total}) => 'Step ${current} of ${total}';
	String get back => 'Back';
	String get next => 'Next';
	String get done => 'Done!';
	String get complete => 'Recipe Complete!';
	String get noSteps => 'No steps available for this recipe.';
	String get backToMealPlan => 'Back to Meal Plan';
	String get backToRecipe => 'Back to Recipe';
}

// Path: favorites
class _StringsFavoritesEn {
	_StringsFavoritesEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get title => 'Favourites';
	String get empty => 'Save recipes you love!';
}

// Path: profile
class _StringsProfileEn {
	_StringsProfileEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get title => 'Profile';
	String get language => 'Language';
	String get units => 'Measurement Units';
	String get subscription => 'Subscription';
	String get logout => 'Sign Out';
	String get theme => 'Theme';
	String get themeSystem => 'System';
	String get themeLight => 'Light';
	String get themeDark => 'Dark';
	String get family => 'Family';
	String get familyNone => 'Not in a family';
	String get preferences => 'PREFERENCES';
}

// Path: units
class _StringsUnitsEn {
	_StringsUnitsEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get metric => 'Metric';
	String get imperial => 'Imperial';
	String get gram => 'g';
	String get kilogram => 'kg';
	String get milliliter => 'ml';
	String get liter => 'l';
	String get teaspoon => 'tsp';
	String get tablespoon => 'tbsp';
	String get cup => 'cup';
	String get ounce => 'oz';
	String get pound => 'lb';
}

// Path: subscription
class _StringsSubscriptionEn {
	_StringsSubscriptionEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get free => 'Free';
	String get trial => 'Trial';
	String get premium => 'Premium';
	String get upgrade => 'Upgrade to Premium';
	String get comingSoon => 'Payment coming soon!';
	String get title => 'Choose a plan';
	String get heading => 'Upgrade PlateFlow';
	String get subtitle => 'Choose the plan that works for you';
	String get forever => 'Forever';
	String get trialPeriod => '14 days';
	String get perMonth => 'per month';
	String get freeFeature1 => '5 recipes for the next 7 days';
	String get freeFeature2 => 'Plan ahead only — no history';
	String get freeFeature3 => 'Basic search';
	String get unlimitedRecipes => 'Unlimited recipes';
	String get unlimitedPlans => 'Unlimited meal plans';
	String get shoppingExport => 'Shopping list export';
	String get delivery => 'Delivery integration';
	String get prioritySupport => 'Priority support';
	String get currentPlan => 'Current plan';
	String get trialUsed => 'Trial used';
	String get startTrial => 'Start trial';
	String get getPremium => 'Get Premium';
	String get premiumActivated => 'Premium activated!';
	String get trialStarted => '14-day trial started!';
	String get active => 'Active';
	String get popular => 'Popular';
	String get upgradeShort => 'Upgrade';
}

// Path: auth
class _StringsAuthEn {
	_StringsAuthEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get login => 'Sign In';
	String get register => 'Create Account';
	String get email => 'Email';
	String get password => 'Password';
	String get fullName => 'Full Name';
	String get forgotPassword => 'Forgot password?';
	String get noAccount => 'Don\'t have an account?';
	String get haveAccount => 'Already have an account?';
	String get continueWithGoogle => 'Continue with Google';
	String get or => 'or';
}

// Path: common
class _StringsCommonEn {
	_StringsCommonEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get loading => 'Loading...';
	String get error => 'Something went wrong';
	String get retry => 'Retry';
	String get save => 'Save';
	String get cancel => 'Cancel';
	String get delete => 'Delete';
	String get edit => 'Edit';
	String get search => 'Search';
	String get noResults => 'No results found';
	String get pressBackAgainToExit => 'Press back again to exit';
}

// Path: family
class _StringsFamilyEn {
	_StringsFamilyEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get title => 'Family';
	String get intro => 'Share one meal plan and shopping list with your family. Everyone in the family uses the owner\'s plan.';
	String get create => 'Create a family';
	String get createPremiumOnly => 'Creating a family requires a Premium plan.';
	String get upgrade => 'Upgrade to Premium';
	String get namePlaceholder => 'Family name';
	String get join => 'Join a family';
	String get joinHint => 'Enter the invite code you got from the family owner';
	String get code => 'Invite code';
	String get joinButton => 'Join';
	String get inviteTitle => 'Invite members';
	String get inviteText => 'Share this code. Whoever enters it in PlateFlow → Profile → Family joins your family.';
	String get copied => 'Code copied';
	String get share => 'Share';
	String get newCode => 'New code';
	String get members => 'Members';
	String slotsLeft({required Object count, required Object max}) => '${count} free slots of ${max}';
	String get owner => 'Owner';
	String get you => 'you';
	String get remove => 'Remove';
	String removeConfirm({required Object name}) => 'Remove ${name} from the family? They go back to their own meal plan.';
	String get leave => 'Leave family';
	String get leaveConfirm => 'Leave the family? You go back to your own meal plan.';
	String get dissolve => 'Dissolve family';
	String get dissolveConfirm => 'Dissolve the family? All members go back to their own meal plans.';
	String get cancel => 'Cancel';
	String shareMessage({required Object code}) => 'Join my family in PlateFlow: open Profile → Family → Join and enter the code ${code}';
}

// Path: update
class _StringsUpdateEn {
	_StringsUpdateEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get title => 'Update available';
	String body({required Object version}) => 'PlateFlow ${version} is ready. Your recipes, plans and settings stay as they are.';
	String get later => 'Later';
	String get install => 'Update now';
	String downloading({required Object percent}) => 'Downloading… ${percent}%';
	String get installing => 'Opening the installer…';
	String get permissionHint => 'If Android asks, allow PlateFlow to install apps.';
	String get upToDate => 'You have the latest version';
	String get check => 'Check for updates';
	String get version => 'App version';
	String get failed => 'The update could not be installed. Please try again.';
	String get browser => 'Download in browser';
}

// Path: recipe.difficulty
class _StringsRecipeDifficultyEn {
	_StringsRecipeDifficultyEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get easy => 'Easy';
	String get medium => 'Medium';
	String get hard => 'Hard';
}

// Path: recipe.nutrition
class _StringsRecipeNutritionEn {
	_StringsRecipeNutritionEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get title => 'Nutrition per serving';
	String get calories => 'Calories';
	String get protein => 'Protein';
	String get carbs => 'Carbs';
	String get fat => 'Fat';
	String get fiber => 'Fiber';
	String get sugar => 'Sugar';
	String get saturatedFat => 'Saturated fat';
	String get sodium => 'Sodium';
}

// Path: mealPlan.days
class _StringsMealPlanDaysEn {
	_StringsMealPlanDaysEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get mon => 'Mon';
	String get tue => 'Tue';
	String get wed => 'Wed';
	String get thu => 'Thu';
	String get fri => 'Fri';
	String get sat => 'Sat';
	String get sun => 'Sun';
}

// Path: mealPlan.mealTypes
class _StringsMealPlanMealTypesEn {
	_StringsMealPlanMealTypesEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get breakfast => 'Breakfast';
	String get lunch => 'Lunch';
	String get dinner => 'Dinner';
	String get snack => 'Snack';
}

// Path: shoppingList.categories
class _StringsShoppingListCategoriesEn {
	_StringsShoppingListCategoriesEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get produce => 'Produce';
	String get dairy => 'Dairy';
	String get meat => 'Meat';
	String get seafood => 'Seafood';
	String get grains => 'Bread & grains';
	String get spices => 'Spices';
	String get oils => 'Oils & Fats';
	String get sauces => 'Sauces';
	String get baking => 'Baking';
	String get canned => 'Canned';
	String get frozen => 'Frozen';
	String get beverages => 'Beverages';
	String get other => 'Other';
}

// Path: shoppingList.details
class _StringsShoppingListDetailsEn {
	_StringsShoppingListDetailsEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get quantity => 'Quantity';
	String get fromRecipe => 'From recipe';
	String get per100g => 'Nutrition per 100 g';
	String get calories => 'Calories';
	String get protein => 'Protein';
	String get carbs => 'Carbs';
	String get fat => 'Fat';
	String get markBought => 'Mark as bought';
	String get unmark => 'Back to the list';
	String get openRecipe => 'Open recipe';
}

// Path: <root>
class _StringsBg implements Translations {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	_StringsBg.build({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = TranslationMetadata(
		    locale: AppLocale.bg,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ) {
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <bg>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	@override dynamic operator[](String key) => $meta.getTranslation(key);

	@override late final _StringsBg _root = this; // ignore: unused_field

	// Translations
	@override late final _StringsAppBg app = _StringsAppBg._(_root);
	@override late final _StringsNavBg nav = _StringsNavBg._(_root);
	@override late final _StringsHomeBg home = _StringsHomeBg._(_root);
	@override late final _StringsRecipeBg recipe = _StringsRecipeBg._(_root);
	@override late final _StringsExploreBg explore = _StringsExploreBg._(_root);
	@override late final _StringsMealPlanBg mealPlan = _StringsMealPlanBg._(_root);
	@override late final _StringsShoppingListBg shoppingList = _StringsShoppingListBg._(_root);
	@override late final _StringsCookingBg cooking = _StringsCookingBg._(_root);
	@override late final _StringsFavoritesBg favorites = _StringsFavoritesBg._(_root);
	@override late final _StringsProfileBg profile = _StringsProfileBg._(_root);
	@override late final _StringsUnitsBg units = _StringsUnitsBg._(_root);
	@override late final _StringsSubscriptionBg subscription = _StringsSubscriptionBg._(_root);
	@override late final _StringsAuthBg auth = _StringsAuthBg._(_root);
	@override late final _StringsCommonBg common = _StringsCommonBg._(_root);
	@override late final _StringsFamilyBg family = _StringsFamilyBg._(_root);
	@override late final _StringsUpdateBg update = _StringsUpdateBg._(_root);
}

// Path: app
class _StringsAppBg implements _StringsAppEn {
	_StringsAppBg._(this._root);

	@override final _StringsBg _root; // ignore: unused_field

	// Translations
	@override String get name => 'PlateFlow';
}

// Path: nav
class _StringsNavBg implements _StringsNavEn {
	_StringsNavBg._(this._root);

	@override final _StringsBg _root; // ignore: unused_field

	// Translations
	@override String get home => 'Начало';
	@override String get explore => 'Разгледай';
	@override String get mealPlan => 'Меню';
	@override String get shopping => 'Пазаруване';
	@override String get profile => 'Профил';
}

// Path: home
class _StringsHomeBg implements _StringsHomeEn {
	_StringsHomeBg._(this._root);

	@override final _StringsBg _root; // ignore: unused_field

	// Translations
	@override String get weeklyTitle => 'Предложения за седмицата';
	@override String get trending => 'Популярни';
	@override String get quickMeals => 'Бързи ястия';
	@override String get favorites => 'Любими рецепти';
	@override String get seeAll => 'Виж всички';
}

// Path: recipe
class _StringsRecipeBg implements _StringsRecipeEn {
	_StringsRecipeBg._(this._root);

	@override final _StringsBg _root; // ignore: unused_field

	// Translations
	@override String get ingredients => 'Съставки';
	@override String get steps => 'Стъпки';
	@override String servings({required Object count}) => '${count} порция/и';
	@override String prepTime({required Object minutes}) => 'Подготовка: ${minutes} мин';
	@override String cookTime({required Object minutes}) => 'Готвене: ${minutes} мин';
	@override String totalTime({required Object minutes}) => '${minutes} мин';
	@override late final _StringsRecipeDifficultyBg difficulty = _StringsRecipeDifficultyBg._(_root);
	@override String get portions => 'Порции';
	@override String get description => 'Описание';
	@override String get noSteps => 'Няма налични стъпки.';
	@override String get addToMealPlan => 'Добави към план';
	@override String get addToShoppingList => 'Добави към списъка';
	@override String get startCooking => 'Започни готвене';
	@override late final _StringsRecipeNutritionBg nutrition = _StringsRecipeNutritionBg._(_root);
	@override String get share => 'Сподели';
	@override String get sharedFrom => 'Споделено от PlateFlow';
}

// Path: explore
class _StringsExploreBg implements _StringsExploreEn {
	_StringsExploreBg._(this._root);

	@override final _StringsBg _root; // ignore: unused_field

	// Translations
	@override String get searchHint => 'Търси рецепти, съставки...';
	@override String get categories => 'Категории';
	@override String get cuisines => 'Кухни';
	@override String get filters => 'Филтри';
	@override String get filterByTime => 'Макс. време за готвене';
	@override String get filterByDifficulty => 'Трудност';
	@override String get searchByIngredients => 'Търси по съставки';
	@override String get searchByIngredientsDesc => 'Намери рецепти от продукти в хладилника';
	@override String get ingredientHint => 'Въведи съставка...';
	@override String get findRecipes => 'Намери рецепти';
	@override String get premiumOnly => 'Премиум функция';
	@override String get premiumOnlyDesc => 'Надгради до Премиум, за да търсиш по съставки';
	@override String get randomMeal => 'Случайна рецепта';
}

// Path: mealPlan
class _StringsMealPlanBg implements _StringsMealPlanEn {
	_StringsMealPlanBg._(this._root);

	@override final _StringsBg _root; // ignore: unused_field

	// Translations
	@override String get title => 'Хранителен план';
	@override String get generateShoppingList => 'Генерирай списък за пазар';
	@override String get addMeal => 'Добави ястие';
	@override late final _StringsMealPlanDaysBg days = _StringsMealPlanDaysBg._(_root);
	@override late final _StringsMealPlanMealTypesBg mealTypes = _StringsMealPlanMealTypesBg._(_root);
	@override String get viewPlan => 'Виж план';
	@override String get removeTitle => 'Премахни рецепта';
	@override String removeConfirm({required Object title}) => 'Да премахна ли „${title}“ от хранителния план?';
	@override String get cook => 'Готви';
	@override String get cooked => 'Сготвено';
	@override String get randomMeal => 'Случайна';
	@override String get randomDay => 'Изненадай ме за деня';
	@override String get noRandom => 'Няма рецепти в тази категория';
	@override String get randomServings => 'За колко порции?';
	@override String get randomAdd => 'Добави';
	@override String get move => 'Премести';
	@override String get moveTitle => 'Премести за кой ден?';
	@override String moved({required Object date}) => 'Преместено: ${date}';
	@override String get reroll => 'Друга рецепта';
	@override String get rerollBack => 'Върни предишната';
	@override String rerolled({required Object title}) => 'Сменено с „${title}“';
	@override String get undo => 'Върни';
	@override String get rerollBoughtTitle => 'Вече има купени продукти';
	@override String rerollBoughtBody({required Object title}) => 'За „${title}“ част от продуктите вече са купени. Да я сменя ли с друга рецепта?';
	@override String get rerollSwap => 'Смени';
	@override String get shiftDays => 'Измести дните';
	@override String get shiftTitle => 'Измести плана';
	@override String shiftBody({required Object date}) => 'Всички несготвени рецепти от ${date} нататък ще се изместят напред. Продуктите в количката се местят с тях.';
	@override String get shiftBy => 'С колко дни?';
	@override String get shiftDo => 'Измести';
	@override String shifted({required Object count}) => 'Изместени рецепти: ${count}';
	@override String get shiftNothing => 'Няма рецепти за изместване';
}

// Path: shoppingList
class _StringsShoppingListBg implements _StringsShoppingListEn {
	_StringsShoppingListBg._(this._root);

	@override final _StringsBg _root; // ignore: unused_field

	// Translations
	@override String get title => 'Списък за пазаруване';
	@override String get empty => 'Все още няма продукти. Генерирай от плана!';
	@override String get clearChecked => 'Изчисти отбелязаните';
	@override String itemsCount({required Object checked, required Object total}) => '${checked} / ${total} продукта';
	@override late final _StringsShoppingListCategoriesBg categories = _StringsShoppingListCategoriesBg._(_root);
	@override late final _StringsShoppingListDetailsBg details = _StringsShoppingListDetailsBg._(_root);
	@override String get viewAll => 'Всичко';
	@override String get byDay => 'По дни';
	@override String get noDay => 'Без ден';
	@override String get today => 'Днес';
}

// Path: cooking
class _StringsCookingBg implements _StringsCookingEn {
	_StringsCookingBg._(this._root);

	@override final _StringsBg _root; // ignore: unused_field

	// Translations
	@override String stepOf({required Object current, required Object total}) => 'Стъпка ${current} от ${total}';
	@override String get back => 'Назад';
	@override String get next => 'Напред';
	@override String get done => 'Готово!';
	@override String get complete => 'Рецептата е готова!';
	@override String get noSteps => 'Няма налични стъпки за тази рецепта.';
	@override String get backToMealPlan => 'Към плана';
	@override String get backToRecipe => 'Към рецептата';
}

// Path: favorites
class _StringsFavoritesBg implements _StringsFavoritesEn {
	_StringsFavoritesBg._(this._root);

	@override final _StringsBg _root; // ignore: unused_field

	// Translations
	@override String get title => 'Любими';
	@override String get empty => 'Запази рецепти, които харесваш!';
}

// Path: profile
class _StringsProfileBg implements _StringsProfileEn {
	_StringsProfileBg._(this._root);

	@override final _StringsBg _root; // ignore: unused_field

	// Translations
	@override String get title => 'Профил';
	@override String get language => 'Език';
	@override String get units => 'Мерни единици';
	@override String get subscription => 'Абонамент';
	@override String get logout => 'Изход';
	@override String get theme => 'Тема';
	@override String get themeSystem => 'Системна';
	@override String get themeLight => 'Светла';
	@override String get themeDark => 'Тъмна';
	@override String get family => 'Семейство';
	@override String get familyNone => 'Не сте в семейство';
	@override String get preferences => 'НАСТРОЙКИ';
}

// Path: units
class _StringsUnitsBg implements _StringsUnitsEn {
	_StringsUnitsBg._(this._root);

	@override final _StringsBg _root; // ignore: unused_field

	// Translations
	@override String get metric => 'Метрична';
	@override String get imperial => 'Имперска';
	@override String get gram => 'г';
	@override String get kilogram => 'кг';
	@override String get milliliter => 'мл';
	@override String get liter => 'л';
	@override String get teaspoon => 'ч.л.';
	@override String get tablespoon => 'с.л.';
	@override String get cup => 'чаша';
	@override String get ounce => 'oz';
	@override String get pound => 'lb';
}

// Path: subscription
class _StringsSubscriptionBg implements _StringsSubscriptionEn {
	_StringsSubscriptionBg._(this._root);

	@override final _StringsBg _root; // ignore: unused_field

	// Translations
	@override String get free => 'Безплатен';
	@override String get trial => 'Пробен';
	@override String get premium => 'Премиум';
	@override String get upgrade => 'Надгради до Премиум';
	@override String get comingSoon => 'Плащането идва скоро!';
	@override String get title => 'Избери план';
	@override String get heading => 'Надгради PlateFlow';
	@override String get subtitle => 'Избери плана, който ти пасва';
	@override String get forever => 'Завинаги';
	@override String get trialPeriod => '14 дни';
	@override String get perMonth => 'на месец';
	@override String get freeFeature1 => '5 рецепти за следващите 7 дни';
	@override String get freeFeature2 => 'Само планиране напред — без история';
	@override String get freeFeature3 => 'Основно търсене';
	@override String get unlimitedRecipes => 'Неограничени рецепти';
	@override String get unlimitedPlans => 'Неограничени хранителни планове';
	@override String get shoppingExport => 'Експорт на списъка за пазаруване';
	@override String get delivery => 'Интеграция с доставка';
	@override String get prioritySupport => 'Приоритетна поддръжка';
	@override String get currentPlan => 'Текущ план';
	@override String get trialUsed => 'Пробният период е използван';
	@override String get startTrial => 'Започни пробен период';
	@override String get getPremium => 'Вземи Премиум';
	@override String get premiumActivated => 'Премиум е активиран!';
	@override String get trialStarted => 'Започна 14-дневен пробен период!';
	@override String get active => 'Активен';
	@override String get popular => 'Най-избиран';
	@override String get upgradeShort => 'Надгради';
}

// Path: auth
class _StringsAuthBg implements _StringsAuthEn {
	_StringsAuthBg._(this._root);

	@override final _StringsBg _root; // ignore: unused_field

	// Translations
	@override String get login => 'Вход';
	@override String get register => 'Регистрация';
	@override String get email => 'Имейл';
	@override String get password => 'Парола';
	@override String get fullName => 'Пълно име';
	@override String get forgotPassword => 'Забравена парола?';
	@override String get noAccount => 'Нямаш акаунт?';
	@override String get haveAccount => 'Вече имаш акаунт?';
	@override String get continueWithGoogle => 'Продължи с Google';
	@override String get or => 'или';
}

// Path: common
class _StringsCommonBg implements _StringsCommonEn {
	_StringsCommonBg._(this._root);

	@override final _StringsBg _root; // ignore: unused_field

	// Translations
	@override String get loading => 'Зарежда...';
	@override String get error => 'Нещо се обърка';
	@override String get retry => 'Опитай пак';
	@override String get save => 'Запази';
	@override String get cancel => 'Отказ';
	@override String get delete => 'Изтрий';
	@override String get edit => 'Редактирай';
	@override String get search => 'Търси';
	@override String get noResults => 'Няма намерени резултати';
	@override String get pressBackAgainToExit => 'Натисни назад отново за изход';
}

// Path: family
class _StringsFamilyBg implements _StringsFamilyEn {
	_StringsFamilyBg._(this._root);

	@override final _StringsBg _root; // ignore: unused_field

	// Translations
	@override String get title => 'Семейство';
	@override String get intro => 'Споделяйте едно меню и един списък за пазар със семейството си. Всички в семейството ползват плана на собственика.';
	@override String get create => 'Създай семейство';
	@override String get createPremiumOnly => 'За да създадете семейство, ви трябва Premium план.';
	@override String get upgrade => 'Към Premium';
	@override String get namePlaceholder => 'Име на семейството';
	@override String get join => 'Присъедини се към семейство';
	@override String get joinHint => 'Въведете кода за покана, който сте получили от собственика';
	@override String get code => 'Код за покана';
	@override String get joinButton => 'Присъедини се';
	@override String get inviteTitle => 'Покани членове';
	@override String get inviteText => 'Изпратете този код. Който го въведе в PlateFlow → Профил → Семейство, влиза в семейството ви.';
	@override String get copied => 'Кодът е копиран';
	@override String get share => 'Сподели';
	@override String get newCode => 'Нов код';
	@override String get members => 'Членове';
	@override String slotsLeft({required Object count, required Object max}) => '${count} свободни места от ${max}';
	@override String get owner => 'Собственик';
	@override String get you => 'вие';
	@override String get remove => 'Премахни';
	@override String removeConfirm({required Object name}) => 'Да премахнем ли ${name} от семейството? Връща се към собственото си меню.';
	@override String get leave => 'Напусни семейството';
	@override String get leaveConfirm => 'Да напуснете ли семейството? Връщате се към собственото си меню.';
	@override String get dissolve => 'Разпусни семейството';
	@override String get dissolveConfirm => 'Да разпуснем ли семейството? Всички членове се връщат към собствените си менюта.';
	@override String get cancel => 'Отказ';
	@override String shareMessage({required Object code}) => 'Влез в семейството ми в PlateFlow: Профил → Семейство → Присъедини се и въведи кода ${code}';
}

// Path: update
class _StringsUpdateBg implements _StringsUpdateEn {
	_StringsUpdateBg._(this._root);

	@override final _StringsBg _root; // ignore: unused_field

	// Translations
	@override String get title => 'Има обновление';
	@override String body({required Object version}) => 'PlateFlow ${version} е готова. Рецептите, плановете и настройките ти остават непроменени.';
	@override String get later => 'По-късно';
	@override String get install => 'Обнови сега';
	@override String downloading({required Object percent}) => 'Изтегляне… ${percent}%';
	@override String get installing => 'Отваряне на инсталатора…';
	@override String get permissionHint => 'Ако Android попита, разреши на PlateFlow да инсталира приложения.';
	@override String get upToDate => 'Имаш последната версия';
	@override String get check => 'Провери за обновяване';
	@override String get version => 'Версия на приложението';
	@override String get failed => 'Обновяването не можа да се инсталира. Опитай пак.';
	@override String get browser => 'Изтегли от браузъра';
}

// Path: recipe.difficulty
class _StringsRecipeDifficultyBg implements _StringsRecipeDifficultyEn {
	_StringsRecipeDifficultyBg._(this._root);

	@override final _StringsBg _root; // ignore: unused_field

	// Translations
	@override String get easy => 'Лесно';
	@override String get medium => 'Средно';
	@override String get hard => 'Трудно';
}

// Path: recipe.nutrition
class _StringsRecipeNutritionBg implements _StringsRecipeNutritionEn {
	_StringsRecipeNutritionBg._(this._root);

	@override final _StringsBg _root; // ignore: unused_field

	// Translations
	@override String get title => 'Хранителни стойности на порция';
	@override String get calories => 'Калории';
	@override String get protein => 'Протеин';
	@override String get carbs => 'Въглехидрати';
	@override String get fat => 'Мазнини';
	@override String get fiber => 'Фибри';
	@override String get sugar => 'Захари';
	@override String get saturatedFat => 'Наситени мазнини';
	@override String get sodium => 'Натрий';
}

// Path: mealPlan.days
class _StringsMealPlanDaysBg implements _StringsMealPlanDaysEn {
	_StringsMealPlanDaysBg._(this._root);

	@override final _StringsBg _root; // ignore: unused_field

	// Translations
	@override String get mon => 'Пон';
	@override String get tue => 'Вт';
	@override String get wed => 'Ср';
	@override String get thu => 'Чет';
	@override String get fri => 'Пет';
	@override String get sat => 'Съб';
	@override String get sun => 'Нед';
}

// Path: mealPlan.mealTypes
class _StringsMealPlanMealTypesBg implements _StringsMealPlanMealTypesEn {
	_StringsMealPlanMealTypesBg._(this._root);

	@override final _StringsBg _root; // ignore: unused_field

	// Translations
	@override String get breakfast => 'Закуска';
	@override String get lunch => 'Обяд';
	@override String get dinner => 'Вечеря';
	@override String get snack => 'Снакс';
}

// Path: shoppingList.categories
class _StringsShoppingListCategoriesBg implements _StringsShoppingListCategoriesEn {
	_StringsShoppingListCategoriesBg._(this._root);

	@override final _StringsBg _root; // ignore: unused_field

	// Translations
	@override String get produce => 'Плодове и зеленчуци';
	@override String get dairy => 'Млечни продукти';
	@override String get meat => 'Месо';
	@override String get seafood => 'Морски дарове';
	@override String get grains => 'Хляб и зърнени';
	@override String get spices => 'Подправки';
	@override String get oils => 'Масла и мазнини';
	@override String get sauces => 'Сосове';
	@override String get baking => 'За печене';
	@override String get canned => 'Консерви';
	@override String get frozen => 'Замразени';
	@override String get beverages => 'Напитки';
	@override String get other => 'Друго';
}

// Path: shoppingList.details
class _StringsShoppingListDetailsBg implements _StringsShoppingListDetailsEn {
	_StringsShoppingListDetailsBg._(this._root);

	@override final _StringsBg _root; // ignore: unused_field

	// Translations
	@override String get quantity => 'Количество';
	@override String get fromRecipe => 'От рецепта';
	@override String get per100g => 'Хранителни стойности на 100 г';
	@override String get calories => 'Калории';
	@override String get protein => 'Протеин';
	@override String get carbs => 'Въглехидрати';
	@override String get fat => 'Мазнини';
	@override String get markBought => 'Отбележи като купено';
	@override String get unmark => 'Върни в списъка';
	@override String get openRecipe => 'Отвори рецептата';
}

/// Flat map(s) containing all translations.
/// Only for edge cases! For simple maps, use the map function of this library.

extension on Translations {
	dynamic _flatMapFunction(String path) {
		switch (path) {
			case 'app.name': return 'PlateFlow';
			case 'nav.home': return 'Home';
			case 'nav.explore': return 'Explore';
			case 'nav.mealPlan': return 'Meal Plan';
			case 'nav.shopping': return 'Shopping';
			case 'nav.profile': return 'Profile';
			case 'home.weeklyTitle': return 'This Week\'s Picks';
			case 'home.trending': return 'Trending Now';
			case 'home.quickMeals': return 'Quick Meals';
			case 'home.favorites': return 'Your favourites';
			case 'home.seeAll': return 'See all';
			case 'recipe.ingredients': return 'Ingredients';
			case 'recipe.steps': return 'Steps';
			case 'recipe.servings': return ({required Object count}) => '${count} serving(s)';
			case 'recipe.prepTime': return ({required Object minutes}) => 'Prep: ${minutes} min';
			case 'recipe.cookTime': return ({required Object minutes}) => 'Cook: ${minutes} min';
			case 'recipe.totalTime': return ({required Object minutes}) => '${minutes} min';
			case 'recipe.difficulty.easy': return 'Easy';
			case 'recipe.difficulty.medium': return 'Medium';
			case 'recipe.difficulty.hard': return 'Hard';
			case 'recipe.portions': return 'Portions';
			case 'recipe.description': return 'Description';
			case 'recipe.noSteps': return 'No steps available.';
			case 'recipe.addToMealPlan': return 'Add to Meal Plan';
			case 'recipe.addToShoppingList': return 'Add to Shopping List';
			case 'recipe.startCooking': return 'Start Cooking';
			case 'recipe.nutrition.title': return 'Nutrition per serving';
			case 'recipe.nutrition.calories': return 'Calories';
			case 'recipe.nutrition.protein': return 'Protein';
			case 'recipe.nutrition.carbs': return 'Carbs';
			case 'recipe.nutrition.fat': return 'Fat';
			case 'recipe.nutrition.fiber': return 'Fiber';
			case 'recipe.nutrition.sugar': return 'Sugar';
			case 'recipe.nutrition.saturatedFat': return 'Saturated fat';
			case 'recipe.nutrition.sodium': return 'Sodium';
			case 'recipe.share': return 'Share';
			case 'recipe.sharedFrom': return 'Shared from PlateFlow';
			case 'explore.searchHint': return 'Search recipes, ingredients...';
			case 'explore.categories': return 'Categories';
			case 'explore.cuisines': return 'Cuisines';
			case 'explore.filters': return 'Filters';
			case 'explore.filterByTime': return 'Max Cook Time';
			case 'explore.filterByDifficulty': return 'Difficulty';
			case 'explore.searchByIngredients': return 'Search by Ingredients';
			case 'explore.searchByIngredientsDesc': return 'Find recipes using what\'s in your fridge';
			case 'explore.ingredientHint': return 'Type an ingredient...';
			case 'explore.findRecipes': return 'Find Recipes';
			case 'explore.premiumOnly': return 'Premium Feature';
			case 'explore.premiumOnlyDesc': return 'Upgrade to Premium to search recipes by ingredients';
			case 'explore.randomMeal': return 'Random meal';
			case 'mealPlan.title': return 'Meal Plan';
			case 'mealPlan.generateShoppingList': return 'Generate Shopping List';
			case 'mealPlan.addMeal': return 'Add Meal';
			case 'mealPlan.days.mon': return 'Mon';
			case 'mealPlan.days.tue': return 'Tue';
			case 'mealPlan.days.wed': return 'Wed';
			case 'mealPlan.days.thu': return 'Thu';
			case 'mealPlan.days.fri': return 'Fri';
			case 'mealPlan.days.sat': return 'Sat';
			case 'mealPlan.days.sun': return 'Sun';
			case 'mealPlan.mealTypes.breakfast': return 'Breakfast';
			case 'mealPlan.mealTypes.lunch': return 'Lunch';
			case 'mealPlan.mealTypes.dinner': return 'Dinner';
			case 'mealPlan.mealTypes.snack': return 'Snack';
			case 'mealPlan.viewPlan': return 'View Plan';
			case 'mealPlan.removeTitle': return 'Remove recipe';
			case 'mealPlan.removeConfirm': return ({required Object title}) => 'Remove "${title}" from your meal plan?';
			case 'mealPlan.cook': return 'Cook';
			case 'mealPlan.cooked': return 'Cooked';
			case 'mealPlan.randomMeal': return 'Random';
			case 'mealPlan.randomDay': return 'Surprise me for the day';
			case 'mealPlan.noRandom': return 'No recipes in this category';
			case 'mealPlan.randomServings': return 'How many servings?';
			case 'mealPlan.randomAdd': return 'Add';
			case 'mealPlan.move': return 'Move';
			case 'mealPlan.moveTitle': return 'Move to which day?';
			case 'mealPlan.moved': return ({required Object date}) => 'Moved: ${date}';
			case 'mealPlan.reroll': return 'Another recipe';
			case 'mealPlan.rerollBack': return 'Bring back the previous one';
			case 'mealPlan.rerolled': return ({required Object title}) => 'Swapped for “${title}”';
			case 'mealPlan.undo': return 'Undo';
			case 'mealPlan.rerollBoughtTitle': return 'Products already bought';
			case 'mealPlan.rerollBoughtBody': return ({required Object title}) => 'Some products for “${title}” were already bought. Swap it for another recipe?';
			case 'mealPlan.rerollSwap': return 'Swap';
			case 'mealPlan.shiftDays': return 'Shift days';
			case 'mealPlan.shiftTitle': return 'Shift the plan';
			case 'mealPlan.shiftBody': return ({required Object date}) => 'All uncooked recipes from ${date} on will move forward. Their products in the cart move with them.';
			case 'mealPlan.shiftBy': return 'By how many days?';
			case 'mealPlan.shiftDo': return 'Shift';
			case 'mealPlan.shifted': return ({required Object count}) => 'Recipes shifted: ${count}';
			case 'mealPlan.shiftNothing': return 'No recipes to shift';
			case 'shoppingList.title': return 'Shopping List';
			case 'shoppingList.empty': return 'No items yet. Generate from your meal plan!';
			case 'shoppingList.clearChecked': return 'Clear Checked';
			case 'shoppingList.itemsCount': return ({required Object checked, required Object total}) => '${checked} / ${total} items';
			case 'shoppingList.categories.produce': return 'Produce';
			case 'shoppingList.categories.dairy': return 'Dairy';
			case 'shoppingList.categories.meat': return 'Meat';
			case 'shoppingList.categories.seafood': return 'Seafood';
			case 'shoppingList.categories.grains': return 'Bread & grains';
			case 'shoppingList.categories.spices': return 'Spices';
			case 'shoppingList.categories.oils': return 'Oils & Fats';
			case 'shoppingList.categories.sauces': return 'Sauces';
			case 'shoppingList.categories.baking': return 'Baking';
			case 'shoppingList.categories.canned': return 'Canned';
			case 'shoppingList.categories.frozen': return 'Frozen';
			case 'shoppingList.categories.beverages': return 'Beverages';
			case 'shoppingList.categories.other': return 'Other';
			case 'shoppingList.details.quantity': return 'Quantity';
			case 'shoppingList.details.fromRecipe': return 'From recipe';
			case 'shoppingList.details.per100g': return 'Nutrition per 100 g';
			case 'shoppingList.details.calories': return 'Calories';
			case 'shoppingList.details.protein': return 'Protein';
			case 'shoppingList.details.carbs': return 'Carbs';
			case 'shoppingList.details.fat': return 'Fat';
			case 'shoppingList.details.markBought': return 'Mark as bought';
			case 'shoppingList.details.unmark': return 'Back to the list';
			case 'shoppingList.details.openRecipe': return 'Open recipe';
			case 'shoppingList.viewAll': return 'All items';
			case 'shoppingList.byDay': return 'By day';
			case 'shoppingList.noDay': return 'No day';
			case 'shoppingList.today': return 'Today';
			case 'cooking.stepOf': return ({required Object current, required Object total}) => 'Step ${current} of ${total}';
			case 'cooking.back': return 'Back';
			case 'cooking.next': return 'Next';
			case 'cooking.done': return 'Done!';
			case 'cooking.complete': return 'Recipe Complete!';
			case 'cooking.noSteps': return 'No steps available for this recipe.';
			case 'cooking.backToMealPlan': return 'Back to Meal Plan';
			case 'cooking.backToRecipe': return 'Back to Recipe';
			case 'favorites.title': return 'Favourites';
			case 'favorites.empty': return 'Save recipes you love!';
			case 'profile.title': return 'Profile';
			case 'profile.language': return 'Language';
			case 'profile.units': return 'Measurement Units';
			case 'profile.subscription': return 'Subscription';
			case 'profile.logout': return 'Sign Out';
			case 'profile.theme': return 'Theme';
			case 'profile.themeSystem': return 'System';
			case 'profile.themeLight': return 'Light';
			case 'profile.themeDark': return 'Dark';
			case 'profile.family': return 'Family';
			case 'profile.familyNone': return 'Not in a family';
			case 'profile.preferences': return 'PREFERENCES';
			case 'units.metric': return 'Metric';
			case 'units.imperial': return 'Imperial';
			case 'units.gram': return 'g';
			case 'units.kilogram': return 'kg';
			case 'units.milliliter': return 'ml';
			case 'units.liter': return 'l';
			case 'units.teaspoon': return 'tsp';
			case 'units.tablespoon': return 'tbsp';
			case 'units.cup': return 'cup';
			case 'units.ounce': return 'oz';
			case 'units.pound': return 'lb';
			case 'subscription.free': return 'Free';
			case 'subscription.trial': return 'Trial';
			case 'subscription.premium': return 'Premium';
			case 'subscription.upgrade': return 'Upgrade to Premium';
			case 'subscription.comingSoon': return 'Payment coming soon!';
			case 'subscription.title': return 'Choose a plan';
			case 'subscription.heading': return 'Upgrade PlateFlow';
			case 'subscription.subtitle': return 'Choose the plan that works for you';
			case 'subscription.forever': return 'Forever';
			case 'subscription.trialPeriod': return '14 days';
			case 'subscription.perMonth': return 'per month';
			case 'subscription.freeFeature1': return '5 recipes for the next 7 days';
			case 'subscription.freeFeature2': return 'Plan ahead only — no history';
			case 'subscription.freeFeature3': return 'Basic search';
			case 'subscription.unlimitedRecipes': return 'Unlimited recipes';
			case 'subscription.unlimitedPlans': return 'Unlimited meal plans';
			case 'subscription.shoppingExport': return 'Shopping list export';
			case 'subscription.delivery': return 'Delivery integration';
			case 'subscription.prioritySupport': return 'Priority support';
			case 'subscription.currentPlan': return 'Current plan';
			case 'subscription.trialUsed': return 'Trial used';
			case 'subscription.startTrial': return 'Start trial';
			case 'subscription.getPremium': return 'Get Premium';
			case 'subscription.premiumActivated': return 'Premium activated!';
			case 'subscription.trialStarted': return '14-day trial started!';
			case 'subscription.active': return 'Active';
			case 'subscription.popular': return 'Popular';
			case 'subscription.upgradeShort': return 'Upgrade';
			case 'auth.login': return 'Sign In';
			case 'auth.register': return 'Create Account';
			case 'auth.email': return 'Email';
			case 'auth.password': return 'Password';
			case 'auth.fullName': return 'Full Name';
			case 'auth.forgotPassword': return 'Forgot password?';
			case 'auth.noAccount': return 'Don\'t have an account?';
			case 'auth.haveAccount': return 'Already have an account?';
			case 'auth.continueWithGoogle': return 'Continue with Google';
			case 'auth.or': return 'or';
			case 'common.loading': return 'Loading...';
			case 'common.error': return 'Something went wrong';
			case 'common.retry': return 'Retry';
			case 'common.save': return 'Save';
			case 'common.cancel': return 'Cancel';
			case 'common.delete': return 'Delete';
			case 'common.edit': return 'Edit';
			case 'common.search': return 'Search';
			case 'common.noResults': return 'No results found';
			case 'common.pressBackAgainToExit': return 'Press back again to exit';
			case 'family.title': return 'Family';
			case 'family.intro': return 'Share one meal plan and shopping list with your family. Everyone in the family uses the owner\'s plan.';
			case 'family.create': return 'Create a family';
			case 'family.createPremiumOnly': return 'Creating a family requires a Premium plan.';
			case 'family.upgrade': return 'Upgrade to Premium';
			case 'family.namePlaceholder': return 'Family name';
			case 'family.join': return 'Join a family';
			case 'family.joinHint': return 'Enter the invite code you got from the family owner';
			case 'family.code': return 'Invite code';
			case 'family.joinButton': return 'Join';
			case 'family.inviteTitle': return 'Invite members';
			case 'family.inviteText': return 'Share this code. Whoever enters it in PlateFlow → Profile → Family joins your family.';
			case 'family.copied': return 'Code copied';
			case 'family.share': return 'Share';
			case 'family.newCode': return 'New code';
			case 'family.members': return 'Members';
			case 'family.slotsLeft': return ({required Object count, required Object max}) => '${count} free slots of ${max}';
			case 'family.owner': return 'Owner';
			case 'family.you': return 'you';
			case 'family.remove': return 'Remove';
			case 'family.removeConfirm': return ({required Object name}) => 'Remove ${name} from the family? They go back to their own meal plan.';
			case 'family.leave': return 'Leave family';
			case 'family.leaveConfirm': return 'Leave the family? You go back to your own meal plan.';
			case 'family.dissolve': return 'Dissolve family';
			case 'family.dissolveConfirm': return 'Dissolve the family? All members go back to their own meal plans.';
			case 'family.cancel': return 'Cancel';
			case 'family.shareMessage': return ({required Object code}) => 'Join my family in PlateFlow: open Profile → Family → Join and enter the code ${code}';
			case 'update.title': return 'Update available';
			case 'update.body': return ({required Object version}) => 'PlateFlow ${version} is ready. Your recipes, plans and settings stay as they are.';
			case 'update.later': return 'Later';
			case 'update.install': return 'Update now';
			case 'update.downloading': return ({required Object percent}) => 'Downloading… ${percent}%';
			case 'update.installing': return 'Opening the installer…';
			case 'update.permissionHint': return 'If Android asks, allow PlateFlow to install apps.';
			case 'update.upToDate': return 'You have the latest version';
			case 'update.check': return 'Check for updates';
			case 'update.version': return 'App version';
			case 'update.failed': return 'The update could not be installed. Please try again.';
			case 'update.browser': return 'Download in browser';
			default: return null;
		}
	}
}

extension on _StringsBg {
	dynamic _flatMapFunction(String path) {
		switch (path) {
			case 'app.name': return 'PlateFlow';
			case 'nav.home': return 'Начало';
			case 'nav.explore': return 'Разгледай';
			case 'nav.mealPlan': return 'Меню';
			case 'nav.shopping': return 'Пазаруване';
			case 'nav.profile': return 'Профил';
			case 'home.weeklyTitle': return 'Предложения за седмицата';
			case 'home.trending': return 'Популярни';
			case 'home.quickMeals': return 'Бързи ястия';
			case 'home.favorites': return 'Любими рецепти';
			case 'home.seeAll': return 'Виж всички';
			case 'recipe.ingredients': return 'Съставки';
			case 'recipe.steps': return 'Стъпки';
			case 'recipe.servings': return ({required Object count}) => '${count} порция/и';
			case 'recipe.prepTime': return ({required Object minutes}) => 'Подготовка: ${minutes} мин';
			case 'recipe.cookTime': return ({required Object minutes}) => 'Готвене: ${minutes} мин';
			case 'recipe.totalTime': return ({required Object minutes}) => '${minutes} мин';
			case 'recipe.difficulty.easy': return 'Лесно';
			case 'recipe.difficulty.medium': return 'Средно';
			case 'recipe.difficulty.hard': return 'Трудно';
			case 'recipe.portions': return 'Порции';
			case 'recipe.description': return 'Описание';
			case 'recipe.noSteps': return 'Няма налични стъпки.';
			case 'recipe.addToMealPlan': return 'Добави към план';
			case 'recipe.addToShoppingList': return 'Добави към списъка';
			case 'recipe.startCooking': return 'Започни готвене';
			case 'recipe.nutrition.title': return 'Хранителни стойности на порция';
			case 'recipe.nutrition.calories': return 'Калории';
			case 'recipe.nutrition.protein': return 'Протеин';
			case 'recipe.nutrition.carbs': return 'Въглехидрати';
			case 'recipe.nutrition.fat': return 'Мазнини';
			case 'recipe.nutrition.fiber': return 'Фибри';
			case 'recipe.nutrition.sugar': return 'Захари';
			case 'recipe.nutrition.saturatedFat': return 'Наситени мазнини';
			case 'recipe.nutrition.sodium': return 'Натрий';
			case 'recipe.share': return 'Сподели';
			case 'recipe.sharedFrom': return 'Споделено от PlateFlow';
			case 'explore.searchHint': return 'Търси рецепти, съставки...';
			case 'explore.categories': return 'Категории';
			case 'explore.cuisines': return 'Кухни';
			case 'explore.filters': return 'Филтри';
			case 'explore.filterByTime': return 'Макс. време за готвене';
			case 'explore.filterByDifficulty': return 'Трудност';
			case 'explore.searchByIngredients': return 'Търси по съставки';
			case 'explore.searchByIngredientsDesc': return 'Намери рецепти от продукти в хладилника';
			case 'explore.ingredientHint': return 'Въведи съставка...';
			case 'explore.findRecipes': return 'Намери рецепти';
			case 'explore.premiumOnly': return 'Премиум функция';
			case 'explore.premiumOnlyDesc': return 'Надгради до Премиум, за да търсиш по съставки';
			case 'explore.randomMeal': return 'Случайна рецепта';
			case 'mealPlan.title': return 'Хранителен план';
			case 'mealPlan.generateShoppingList': return 'Генерирай списък за пазар';
			case 'mealPlan.addMeal': return 'Добави ястие';
			case 'mealPlan.days.mon': return 'Пон';
			case 'mealPlan.days.tue': return 'Вт';
			case 'mealPlan.days.wed': return 'Ср';
			case 'mealPlan.days.thu': return 'Чет';
			case 'mealPlan.days.fri': return 'Пет';
			case 'mealPlan.days.sat': return 'Съб';
			case 'mealPlan.days.sun': return 'Нед';
			case 'mealPlan.mealTypes.breakfast': return 'Закуска';
			case 'mealPlan.mealTypes.lunch': return 'Обяд';
			case 'mealPlan.mealTypes.dinner': return 'Вечеря';
			case 'mealPlan.mealTypes.snack': return 'Снакс';
			case 'mealPlan.viewPlan': return 'Виж план';
			case 'mealPlan.removeTitle': return 'Премахни рецепта';
			case 'mealPlan.removeConfirm': return ({required Object title}) => 'Да премахна ли „${title}“ от хранителния план?';
			case 'mealPlan.cook': return 'Готви';
			case 'mealPlan.cooked': return 'Сготвено';
			case 'mealPlan.randomMeal': return 'Случайна';
			case 'mealPlan.randomDay': return 'Изненадай ме за деня';
			case 'mealPlan.noRandom': return 'Няма рецепти в тази категория';
			case 'mealPlan.randomServings': return 'За колко порции?';
			case 'mealPlan.randomAdd': return 'Добави';
			case 'mealPlan.move': return 'Премести';
			case 'mealPlan.moveTitle': return 'Премести за кой ден?';
			case 'mealPlan.moved': return ({required Object date}) => 'Преместено: ${date}';
			case 'mealPlan.reroll': return 'Друга рецепта';
			case 'mealPlan.rerollBack': return 'Върни предишната';
			case 'mealPlan.rerolled': return ({required Object title}) => 'Сменено с „${title}“';
			case 'mealPlan.undo': return 'Върни';
			case 'mealPlan.rerollBoughtTitle': return 'Вече има купени продукти';
			case 'mealPlan.rerollBoughtBody': return ({required Object title}) => 'За „${title}“ част от продуктите вече са купени. Да я сменя ли с друга рецепта?';
			case 'mealPlan.rerollSwap': return 'Смени';
			case 'mealPlan.shiftDays': return 'Измести дните';
			case 'mealPlan.shiftTitle': return 'Измести плана';
			case 'mealPlan.shiftBody': return ({required Object date}) => 'Всички несготвени рецепти от ${date} нататък ще се изместят напред. Продуктите в количката се местят с тях.';
			case 'mealPlan.shiftBy': return 'С колко дни?';
			case 'mealPlan.shiftDo': return 'Измести';
			case 'mealPlan.shifted': return ({required Object count}) => 'Изместени рецепти: ${count}';
			case 'mealPlan.shiftNothing': return 'Няма рецепти за изместване';
			case 'shoppingList.title': return 'Списък за пазаруване';
			case 'shoppingList.empty': return 'Все още няма продукти. Генерирай от плана!';
			case 'shoppingList.clearChecked': return 'Изчисти отбелязаните';
			case 'shoppingList.itemsCount': return ({required Object checked, required Object total}) => '${checked} / ${total} продукта';
			case 'shoppingList.categories.produce': return 'Плодове и зеленчуци';
			case 'shoppingList.categories.dairy': return 'Млечни продукти';
			case 'shoppingList.categories.meat': return 'Месо';
			case 'shoppingList.categories.seafood': return 'Морски дарове';
			case 'shoppingList.categories.grains': return 'Хляб и зърнени';
			case 'shoppingList.categories.spices': return 'Подправки';
			case 'shoppingList.categories.oils': return 'Масла и мазнини';
			case 'shoppingList.categories.sauces': return 'Сосове';
			case 'shoppingList.categories.baking': return 'За печене';
			case 'shoppingList.categories.canned': return 'Консерви';
			case 'shoppingList.categories.frozen': return 'Замразени';
			case 'shoppingList.categories.beverages': return 'Напитки';
			case 'shoppingList.categories.other': return 'Друго';
			case 'shoppingList.details.quantity': return 'Количество';
			case 'shoppingList.details.fromRecipe': return 'От рецепта';
			case 'shoppingList.details.per100g': return 'Хранителни стойности на 100 г';
			case 'shoppingList.details.calories': return 'Калории';
			case 'shoppingList.details.protein': return 'Протеин';
			case 'shoppingList.details.carbs': return 'Въглехидрати';
			case 'shoppingList.details.fat': return 'Мазнини';
			case 'shoppingList.details.markBought': return 'Отбележи като купено';
			case 'shoppingList.details.unmark': return 'Върни в списъка';
			case 'shoppingList.details.openRecipe': return 'Отвори рецептата';
			case 'shoppingList.viewAll': return 'Всичко';
			case 'shoppingList.byDay': return 'По дни';
			case 'shoppingList.noDay': return 'Без ден';
			case 'shoppingList.today': return 'Днес';
			case 'cooking.stepOf': return ({required Object current, required Object total}) => 'Стъпка ${current} от ${total}';
			case 'cooking.back': return 'Назад';
			case 'cooking.next': return 'Напред';
			case 'cooking.done': return 'Готово!';
			case 'cooking.complete': return 'Рецептата е готова!';
			case 'cooking.noSteps': return 'Няма налични стъпки за тази рецепта.';
			case 'cooking.backToMealPlan': return 'Към плана';
			case 'cooking.backToRecipe': return 'Към рецептата';
			case 'favorites.title': return 'Любими';
			case 'favorites.empty': return 'Запази рецепти, които харесваш!';
			case 'profile.title': return 'Профил';
			case 'profile.language': return 'Език';
			case 'profile.units': return 'Мерни единици';
			case 'profile.subscription': return 'Абонамент';
			case 'profile.logout': return 'Изход';
			case 'profile.theme': return 'Тема';
			case 'profile.themeSystem': return 'Системна';
			case 'profile.themeLight': return 'Светла';
			case 'profile.themeDark': return 'Тъмна';
			case 'profile.family': return 'Семейство';
			case 'profile.familyNone': return 'Не сте в семейство';
			case 'profile.preferences': return 'НАСТРОЙКИ';
			case 'units.metric': return 'Метрична';
			case 'units.imperial': return 'Имперска';
			case 'units.gram': return 'г';
			case 'units.kilogram': return 'кг';
			case 'units.milliliter': return 'мл';
			case 'units.liter': return 'л';
			case 'units.teaspoon': return 'ч.л.';
			case 'units.tablespoon': return 'с.л.';
			case 'units.cup': return 'чаша';
			case 'units.ounce': return 'oz';
			case 'units.pound': return 'lb';
			case 'subscription.free': return 'Безплатен';
			case 'subscription.trial': return 'Пробен';
			case 'subscription.premium': return 'Премиум';
			case 'subscription.upgrade': return 'Надгради до Премиум';
			case 'subscription.comingSoon': return 'Плащането идва скоро!';
			case 'subscription.title': return 'Избери план';
			case 'subscription.heading': return 'Надгради PlateFlow';
			case 'subscription.subtitle': return 'Избери плана, който ти пасва';
			case 'subscription.forever': return 'Завинаги';
			case 'subscription.trialPeriod': return '14 дни';
			case 'subscription.perMonth': return 'на месец';
			case 'subscription.freeFeature1': return '5 рецепти за следващите 7 дни';
			case 'subscription.freeFeature2': return 'Само планиране напред — без история';
			case 'subscription.freeFeature3': return 'Основно търсене';
			case 'subscription.unlimitedRecipes': return 'Неограничени рецепти';
			case 'subscription.unlimitedPlans': return 'Неограничени хранителни планове';
			case 'subscription.shoppingExport': return 'Експорт на списъка за пазаруване';
			case 'subscription.delivery': return 'Интеграция с доставка';
			case 'subscription.prioritySupport': return 'Приоритетна поддръжка';
			case 'subscription.currentPlan': return 'Текущ план';
			case 'subscription.trialUsed': return 'Пробният период е използван';
			case 'subscription.startTrial': return 'Започни пробен период';
			case 'subscription.getPremium': return 'Вземи Премиум';
			case 'subscription.premiumActivated': return 'Премиум е активиран!';
			case 'subscription.trialStarted': return 'Започна 14-дневен пробен период!';
			case 'subscription.active': return 'Активен';
			case 'subscription.popular': return 'Най-избиран';
			case 'subscription.upgradeShort': return 'Надгради';
			case 'auth.login': return 'Вход';
			case 'auth.register': return 'Регистрация';
			case 'auth.email': return 'Имейл';
			case 'auth.password': return 'Парола';
			case 'auth.fullName': return 'Пълно име';
			case 'auth.forgotPassword': return 'Забравена парола?';
			case 'auth.noAccount': return 'Нямаш акаунт?';
			case 'auth.haveAccount': return 'Вече имаш акаунт?';
			case 'auth.continueWithGoogle': return 'Продължи с Google';
			case 'auth.or': return 'или';
			case 'common.loading': return 'Зарежда...';
			case 'common.error': return 'Нещо се обърка';
			case 'common.retry': return 'Опитай пак';
			case 'common.save': return 'Запази';
			case 'common.cancel': return 'Отказ';
			case 'common.delete': return 'Изтрий';
			case 'common.edit': return 'Редактирай';
			case 'common.search': return 'Търси';
			case 'common.noResults': return 'Няма намерени резултати';
			case 'common.pressBackAgainToExit': return 'Натисни назад отново за изход';
			case 'family.title': return 'Семейство';
			case 'family.intro': return 'Споделяйте едно меню и един списък за пазар със семейството си. Всички в семейството ползват плана на собственика.';
			case 'family.create': return 'Създай семейство';
			case 'family.createPremiumOnly': return 'За да създадете семейство, ви трябва Premium план.';
			case 'family.upgrade': return 'Към Premium';
			case 'family.namePlaceholder': return 'Име на семейството';
			case 'family.join': return 'Присъедини се към семейство';
			case 'family.joinHint': return 'Въведете кода за покана, който сте получили от собственика';
			case 'family.code': return 'Код за покана';
			case 'family.joinButton': return 'Присъедини се';
			case 'family.inviteTitle': return 'Покани членове';
			case 'family.inviteText': return 'Изпратете този код. Който го въведе в PlateFlow → Профил → Семейство, влиза в семейството ви.';
			case 'family.copied': return 'Кодът е копиран';
			case 'family.share': return 'Сподели';
			case 'family.newCode': return 'Нов код';
			case 'family.members': return 'Членове';
			case 'family.slotsLeft': return ({required Object count, required Object max}) => '${count} свободни места от ${max}';
			case 'family.owner': return 'Собственик';
			case 'family.you': return 'вие';
			case 'family.remove': return 'Премахни';
			case 'family.removeConfirm': return ({required Object name}) => 'Да премахнем ли ${name} от семейството? Връща се към собственото си меню.';
			case 'family.leave': return 'Напусни семейството';
			case 'family.leaveConfirm': return 'Да напуснете ли семейството? Връщате се към собственото си меню.';
			case 'family.dissolve': return 'Разпусни семейството';
			case 'family.dissolveConfirm': return 'Да разпуснем ли семейството? Всички членове се връщат към собствените си менюта.';
			case 'family.cancel': return 'Отказ';
			case 'family.shareMessage': return ({required Object code}) => 'Влез в семейството ми в PlateFlow: Профил → Семейство → Присъедини се и въведи кода ${code}';
			case 'update.title': return 'Има обновление';
			case 'update.body': return ({required Object version}) => 'PlateFlow ${version} е готова. Рецептите, плановете и настройките ти остават непроменени.';
			case 'update.later': return 'По-късно';
			case 'update.install': return 'Обнови сега';
			case 'update.downloading': return ({required Object percent}) => 'Изтегляне… ${percent}%';
			case 'update.installing': return 'Отваряне на инсталатора…';
			case 'update.permissionHint': return 'Ако Android попита, разреши на PlateFlow да инсталира приложения.';
			case 'update.upToDate': return 'Имаш последната версия';
			case 'update.check': return 'Провери за обновяване';
			case 'update.version': return 'Версия на приложението';
			case 'update.failed': return 'Обновяването не можа да се инсталира. Опитай пак.';
			case 'update.browser': return 'Изтегли от браузъра';
			default: return null;
		}
	}
}
