import pytest
import os
import importlib

import arkouda as ak

from server_util.test.server_test_util import (
    TestRunningMode,
    is_multilocale_arkouda,  # TODO probably not needed
    start_arkouda_server,
    stop_arkouda_server,
)


def pytest_addoption(parser):
    parser.addoption(
        "--optional-parquet", action="store_true", default=False, help="run optional parquet tests"
    )
    parser.addoption(
        "--nl", action="store", default="2",
        help="Number of Locales to run Arkouda with. "
             "Defaults to 2. If Arkouda is not configured for multi_locale, 1 locale is used"
    )
    parser.addoption(
        "--size", action="store", default="10**8",
        help="Problem size: length of array to use for tests/benchmarks. For some cases, this will "
             "be multiplied by the number of locales."
    )
    parser.addoption(
        "--seed", action="store", default="",
        help="Value to initialize random number generator."
    )

def pytest_collection_modifyitems(config, items):
    if config.getoption("--optional-parquet"):
        # --optional-parquet given in cli: do not skip optional parquet tests
        return
    skip_parquet = pytest.mark.skip(reason="need --optional-parquet option to run")
    for item in items:
        if "optional_parquet" in item.keywords:
            item.add_marker(skip_parquet)


def _get_test_locales(config):
    """
    Set the number of locales to run Arkouda with.
    The default is 2 provided Arkouda is configured for multi-locale.
    Otherwise, 1 locale will be used
    """
    return eval(config.getoption("nl")) if is_multilocale_arkouda() else 1


def pytest_configure(config):
    config.addinivalue_line("markers", "optional_parquet: mark test as slow to run")
    pytest.port = int(os.getenv("ARKOUDA_SERVER_PORT", 5555))
    pytest.server = os.getenv("ARKOUDA_SERVER_HOST", "localhost")
    pytest.timeout = int(os.getenv("ARKOUDA_CLIENT_TIMEOUT", 5))
    pytest.verbose = bool(os.getenv("ARKOUDA_VERBOSE", False))
    pytest.nl = _get_test_locales(config)
    pytest.seed = None if config.getoption("seed") == "" else eval(config.getoption("seed"))
    pytest.prob_size = [eval(x) for x in config.getoption("size").split(",")]


@pytest.fixture(scope="session", autouse=True)
def startup_teardown():
    test_running_mode = TestRunningMode(os.getenv("ARKOUDA_RUNNING_MODE", "CLASS_SERVER"))

    if not importlib.util.find_spec("pytest") or not importlib.util.find_spec("pytest_env"):
        raise EnvironmentError("pytest and pytest-env must be installed")
    if TestRunningMode.CLASS_SERVER == test_running_mode:
        try:
            pytest.server, _, _ = start_arkouda_server(numlocales=pytest.nl, port=pytest.port)
            print(
                "Started arkouda_server in TEST_CLASS mode with "
                "host: {} port: {} locales: {}".format(pytest.server, pytest.port, pytest.nl)
            )
        except Exception as e:
            raise RuntimeError(
                f"in configuring or starting the arkouda_server: {e}, check "
                + "environment and/or arkouda_server installation"
            )
    else:
        print(
            "in client stack test mode with host: {} port: {}".format(
                pytest.server, pytest.port
            )
        )

    yield

    if TestRunningMode.CLASS_SERVER == test_running_mode:
        try:
            stop_arkouda_server()
        except Exception:
            pass


@pytest.fixture(scope="class", autouse=True)
def manage_connection():
    try:
        ak.connect(
            server=pytest.server, port=pytest.port, timeout=pytest.timeout
        )
    except Exception as e:
        raise ConnectionError(e)

    yield

    try:
        ak.disconnect()
    except Exception as e:
        raise ConnectionError(e)
