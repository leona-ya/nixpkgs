{ lib
, buildPythonPackage
, fetchPypi
, pythonOlder
}:

buildPythonPackage rec {
  pname = "python-ipware";
  version = "0.9.0";
  format = "setuptools";

  disabled = pythonOlder "3.7";

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-7oTNFsLPhi+q4ZetX4+ubHXksfQLsTNXlEpdY93Co3M=";
  };

  meta = with lib; {
    description = "A python package for server applications to retrieve client's IP address";
    homepage = "https://github.com/un33k/python-ipware";
    changelog = "https://github.com/un33k/python-ipware/blob/v${version}/CHANGELOG.md";

    license = licenses.mit;
    maintainers = with maintainers; [ e1mo ];
  };
}
