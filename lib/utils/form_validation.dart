bool validarFormulario({
  required String peso,
  required String altura,
  required String fecha,
}) {
  final int? pesoVal = int.tryParse(peso);
  final double? alturaVal = double.tryParse(altura);

  return pesoVal != null &&
      pesoVal >= 30 &&
      pesoVal <= 300 &&
      alturaVal != null &&
      alturaVal >= 0.5 &&
      alturaVal <= 3.0 &&
      fecha.isNotEmpty;
}
