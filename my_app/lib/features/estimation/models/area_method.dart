/// How a bill counts a window's feet.
///
/// "running" when the workshop bills in running feet (Karachi's way: a small
/// window by its four sides added up -- see the server's running_feet.js);
/// anything else, including every bill made before, is square feet.
const String runningFeetAreaMethod = 'running';

/// The unit to print beside a bill's feet: "Rn.ft" or "sq.ft".
String areaUnitFor(String areaMethod) =>
    areaMethod == runningFeetAreaMethod ? 'Rn.ft' : 'sq.ft';
