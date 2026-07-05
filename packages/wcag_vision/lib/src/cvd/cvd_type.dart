/// A type of colour vision deficiency (CVD) that can be simulated.
///
/// The three dichromatic deficiencies correspond to the complete absence of
/// one of the eye's three cone photoreceptor classes. Together they cover the
/// conditions a designer most needs to check against; anomalous trichromacy
/// (partial deficiency) is milder than the dichromacy simulated here, so a
/// palette that survives these transforms is safe for the milder forms too.
enum CvdType {
  /// Normal colour vision — no deficiency.
  ///
  /// Simulation with this type is the identity transform and returns the
  /// input colour unchanged. Included so UI toggles can treat "normal
  /// vision" as just another selectable state.
  none,

  /// Protanopia — absence of L ("long"-wavelength, red-sensitive) cones.
  ///
  /// Reds appear darker and are confused with greens, browns, and dark
  /// oranges. Affects roughly 1% of males.
  protanopia,

  /// Deuteranopia — absence of M ("medium"-wavelength, green-sensitive)
  /// cones.
  ///
  /// Greens and reds are confused, without protanopia's darkening of red.
  /// The most common dichromacy, affecting roughly 1–1.5% of males.
  deuteranopia,

  /// Tritanopia — absence of S ("short"-wavelength, blue-sensitive) cones.
  ///
  /// Blues are confused with greens, and yellows with violets and light
  /// greys. Very rare (well under 0.1%), and unlike the red–green types it
  /// affects both sexes equally.
  tritanopia,
}
