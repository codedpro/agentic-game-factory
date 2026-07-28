#!/usr/bin/env python3
"""Server tests — stdlib unittest, no network, no dependencies.

Run: python3 server/test_server.py

The store calls are stubbed. The one thing NOT stubbed anywhere is the distinction that
matters most: "the store says this receipt is fake" (deny) versus "we could not reach the
store" (never deny) — both are exercised explicitly.
"""
import os
import sqlite3
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import accounts
import bazaar
import purchases


def memdb():
    conn = sqlite3.connect(":memory:")
    conn.row_factory = sqlite3.Row
    accounts.init_db(conn)
    purchases.init_db(conn)
    return conn


class PasswordHashing(unittest.TestCase):
    def test_hash_is_salted_and_verifies(self):
        a = accounts.hash_password("correct horse battery")
        b = accounts.hash_password("correct horse battery")
        self.assertNotEqual(a, b, "identical passwords must not produce identical hashes")
        self.assertTrue(accounts.verify_password("correct horse battery", a))
        self.assertTrue(accounts.verify_password("correct horse battery", b))

    def test_wrong_password_fails(self):
        h = accounts.hash_password("hunter2hunter2")
        self.assertFalse(accounts.verify_password("hunter2hunter3", h))
        self.assertFalse(accounts.verify_password("", h))

    def test_plaintext_never_appears_in_the_hash(self):
        h = accounts.hash_password("swordfish-1234")
        self.assertNotIn("swordfish", h)

    def test_malformed_stored_hash_is_false_not_an_exception(self):
        for junk in ["", "nonsense", "scrypt$x$y$z$aa$bb", "md5$1$2$3$aa$bb"]:
            self.assertFalse(accounts.verify_password("whatever", junk))


class Validation(unittest.TestCase):
    def test_emails(self):
        for good in ["a@b.co", "player.one+tag@mail.example.ir", "ali@gmail.com"]:
            self.assertTrue(accounts.valid_email(good), good)
        for bad in ["", "no-at-sign", "a@b", "a@@b.co", "a b@c.co", "a@b.", "@b.co"]:
            self.assertFalse(accounts.valid_email(bad), bad)

    def test_password_rules(self):
        self.assertEqual(accounts.password_problem("12345678"), "")
        self.assertEqual(accounts.password_problem("short"), "password_short")
        self.assertEqual(accounts.password_problem("x" * 200), "password_long")
        self.assertEqual(accounts.password_problem("        "), "password_short")


class RegisterLogin(unittest.TestCase):
    def setUp(self):
        self.conn = memdb()
        accounts.reset_throttle()
        self.body = {"email": "Ali@Example.com", "password": "goodpassword1",
                     "device_id": "dev1"}

    def test_register_then_login(self):
        code, payload = accounts.register(self.conn, "mergedrop", self.body, "1.1.1.1")
        self.assertEqual(code, 200)
        self.assertTrue(payload["token"])
        code, payload = accounts.login(self.conn, "mergedrop", self.body, "1.1.1.1")
        self.assertEqual(code, 200)
        self.assertTrue(payload["token"])

    def test_email_is_case_insensitive_for_identity(self):
        accounts.register(self.conn, "mergedrop", self.body, "1.1.1.1")
        code, _ = accounts.login(self.conn, "mergedrop",
                                 {**self.body, "email": "ALI@EXAMPLE.COM"}, "1.1.1.1")
        self.assertEqual(code, 200, "the same address in another case is the same account")

    def test_duplicate_registration_is_rejected_without_logging_in(self):
        accounts.register(self.conn, "mergedrop", self.body, "1.1.1.1")
        code, payload = accounts.register(
            self.conn, "mergedrop", {**self.body, "password": "attacker-guess"}, "2.2.2.2")
        self.assertEqual(code, 409)
        self.assertNotIn("token", payload,
                         "re-registering must never hand out a session")

    def test_bad_password_is_rejected(self):
        accounts.register(self.conn, "mergedrop", self.body, "1.1.1.1")
        code, _ = accounts.login(self.conn, "mergedrop",
                                 {**self.body, "password": "wrongwrong"}, "1.1.1.1")
        self.assertEqual(code, 401)

    def test_unknown_account_and_wrong_password_look_identical(self):
        accounts.register(self.conn, "mergedrop", self.body, "1.1.1.1")
        _, a = accounts.login(self.conn, "mergedrop",
                              {**self.body, "password": "wrongwrong"}, "1.1.1.1")
        accounts.reset_throttle()
        _, b = accounts.login(self.conn, "mergedrop",
                              {"email": "nobody@example.com", "password": "wrongwrong"},
                              "1.1.1.1")
        self.assertEqual(a, b, "the error must not reveal whether the email exists")

    def test_weak_password_refused_at_registration(self):
        code, payload = accounts.register(
            self.conn, "mergedrop", {**self.body, "password": "short"}, "1.1.1.1")
        self.assertEqual(code, 400)
        self.assertEqual(payload["error"], "password_short")

    def test_accounts_are_per_game(self):
        accounts.register(self.conn, "mergedrop", self.body, "1.1.1.1")
        code, _ = accounts.login(self.conn, "othergame", self.body, "1.1.1.1")
        self.assertEqual(code, 401, "one game's account must not log into another")

    def test_login_throttled_after_repeated_failures(self):
        accounts.register(self.conn, "mergedrop", self.body, "1.1.1.1")
        wrong = {**self.body, "password": "wrongwrong"}
        codes = [accounts.login(self.conn, "mergedrop", wrong, "9.9.9.9")[0]
                 for _ in range(accounts.LOGIN_MAX_FAILS + 2)]
        self.assertIn(429, codes, "brute forcing must eventually be throttled")

    def test_a_correct_login_clears_the_failure_counter(self):
        accounts.register(self.conn, "mergedrop", self.body, "1.1.1.1")
        wrong = {**self.body, "password": "wrongwrong"}
        for _ in range(accounts.LOGIN_MAX_FAILS - 1):
            accounts.login(self.conn, "mergedrop", wrong, "3.3.3.3")
        self.assertEqual(accounts.login(self.conn, "mergedrop", self.body, "3.3.3.3")[0], 200)
        self.assertEqual(accounts.login(self.conn, "mergedrop", self.body, "3.3.3.3")[0], 200)


class Sessions(unittest.TestCase):
    def setUp(self):
        self.conn = memdb()
        accounts.reset_throttle()
        _, payload = accounts.register(
            self.conn, "mergedrop",
            {"email": "s@e.com", "password": "goodpassword1", "device_id": "d"}, "1.1.1.1")
        self.token = payload["token"]

    def test_token_resolves_to_its_owner(self):
        self.assertEqual(accounts.session_owner(self.conn, "mergedrop", self.token),
                         "s@e.com")

    def test_only_the_hash_of_a_token_is_stored(self):
        rows = self.conn.execute("SELECT token_hash FROM sessions").fetchall()
        self.assertTrue(rows)
        for r in rows:
            self.assertNotEqual(r["token_hash"], self.token,
                                "a stolen database must not yield usable tokens")

    def test_garbage_and_foreign_game_tokens_are_rejected(self):
        self.assertIsNone(accounts.session_owner(self.conn, "mergedrop", "nope"))
        self.assertIsNone(accounts.session_owner(self.conn, "mergedrop", ""))
        self.assertIsNone(accounts.session_owner(self.conn, "othergame", self.token))

    def test_logout_invalidates_the_token(self):
        accounts.logout(self.conn, "mergedrop", {"token": self.token})
        self.assertIsNone(accounts.session_owner(self.conn, "mergedrop", self.token))

    def test_expired_session_is_rejected(self):
        self.conn.execute("UPDATE sessions SET expires=1")
        self.assertIsNone(accounts.session_owner(self.conn, "mergedrop", self.token))


class PurchaseVerification(unittest.TestCase):
    def setUp(self):
        self.conn = memdb()
        self.body = {"store": "myket", "product_id": "coins_small",
                     "purchase_token": "tok-abc", "device_id": "dev1"}
        self._real = purchases.check_myket

    def tearDown(self):
        purchases.check_myket = self._real

    def _stub(self, result):
        def fake(package, product_id, token):
            if isinstance(result, Exception):
                raise result
            return result
        purchases.check_myket = fake

    def test_a_real_receipt_is_granted_once(self):
        self._stub(True)
        code, payload = purchases.verify(self.conn, "mergedrop", "pkg", self.body, "a@b.co")
        self.assertEqual(code, 200)
        self.assertTrue(payload["granted"])

    def test_the_same_receipt_is_never_granted_twice(self):
        self._stub(True)
        purchases.verify(self.conn, "mergedrop", "pkg", self.body, "a@b.co")
        code, payload = purchases.verify(self.conn, "mergedrop", "pkg", self.body, "a@b.co")
        self.assertEqual(code, 200)
        self.assertFalse(payload["granted"], "a replayed receipt must not pay out again")
        self.assertTrue(payload["already"])

    def test_another_account_cannot_redeem_someone_elses_receipt(self):
        self._stub(True)
        purchases.verify(self.conn, "mergedrop", "pkg", self.body, "a@b.co")
        code, payload = purchases.verify(self.conn, "mergedrop", "pkg", self.body, "thief@x.co")
        self.assertFalse(payload["granted"])
        self.assertFalse(payload["mine"])

    def test_a_fake_receipt_is_refused(self):
        self._stub(False)
        code, payload = purchases.verify(self.conn, "mergedrop", "pkg", self.body, "a@b.co")
        self.assertEqual(code, 402)
        self.assertEqual(payload["error"], "invalid_receipt")
        left = self.conn.execute("SELECT COUNT(*) c FROM purchases").fetchone()["c"]
        self.assertEqual(left, 0, "a refused receipt must not be recorded as owned")

    def test_an_unreachable_store_is_not_a_denial(self):
        self._stub(purchases.StoreUnreachable("network down"))
        code, payload = purchases.verify(self.conn, "mergedrop", "pkg", self.body, "a@b.co")
        self.assertEqual(code, 503, "503 tells the client to keep the receipt and retry")
        self.assertNotEqual(code, 402, "never call a paying player a fraud on a timeout")

    def test_bazaar_is_recorded_but_flagged_unverified(self):
        code, payload = purchases.verify(
            self.conn, "mergedrop", "pkg", {**self.body, "store": "bazaar"}, "a@b.co")
        self.assertEqual(code, 200)
        self.assertTrue(payload["granted"])
        self.assertFalse(payload["verified"],
                         "Bazaar has no server check yet — say so, do not imply one")

    def test_junk_input_is_rejected(self):
        for bad in [{}, {**self.body, "store": "steam"},
                    {**self.body, "purchase_token": ""},
                    {**self.body, "product_id": ""}]:
            code, _ = purchases.verify(self.conn, "mergedrop", "pkg", bad, "a@b.co")
            self.assertEqual(code, 400, bad)

    def test_history_lists_only_your_own_purchases(self):
        self._stub(True)
        purchases.verify(self.conn, "mergedrop", "pkg", self.body, "a@b.co")
        purchases.verify(self.conn, "mergedrop", "pkg",
                         {**self.body, "purchase_token": "tok-2"}, "other@b.co")
        _, payload = purchases.history(self.conn, "mergedrop", "a@b.co")
        self.assertEqual(len(payload["purchases"]), 1)


class MyketApiContract(unittest.TestCase):
    """The shape confirmed against the live API on 2026-07-27 (see purchases.py docs)."""

    def test_denial_and_unreachable_are_distinguished(self):
        import urllib.error

        def raise_http(code, body):
            def fake(req, timeout=0):
                raise urllib.error.HTTPError(req.full_url, code, "err", {},
                                             _FakeBody(body))
            return fake

        real = purchases.urllib.request.urlopen
        purchases._myket_key_cache = "test-key"
        try:
            # a valid key with a bogus token: the store denies -> False, not an exception
            purchases.urllib.request.urlopen = raise_http(
                400, '{"code":400,"messageCode":"InvalidToken"}')
            self.assertFalse(purchases.check_myket("pkg", "sku", "bogus"))
            # our credentials rejected: unknown, must NOT read as a fake receipt
            purchases.urllib.request.urlopen = raise_http(
                401, '{"code":401,"messageCode":"Unauthorized"}')
            with self.assertRaises(purchases.StoreUnreachable):
                purchases.check_myket("pkg", "sku", "whatever")
        finally:
            purchases.urllib.request.urlopen = real
            purchases._myket_key_cache = None

    def test_a_missing_access_key_never_denies_a_player(self):
        purchases._myket_key_cache = ""
        try:
            with self.assertRaises(purchases.StoreUnreachable):
                purchases.check_myket("pkg", "sku", "tok")
        finally:
            purchases._myket_key_cache = None


class BazaarOAuth(unittest.TestCase):
    """The same three-outcome rule as Myket: confirmed / denied / unknown."""

    def setUp(self):
        bazaar.reset_cache()
        self._real = bazaar._access
        bazaar._access = lambda: "fake-access-token"

    def tearDown(self):
        bazaar._access = self._real
        bazaar.reset_cache()

    def _http_error(self, code, body=""):
        import urllib.error

        def fake(url, timeout=0):
            raise urllib.error.HTTPError(
                getattr(url, "full_url", str(url)), code, "err", {}, _FakeBody(body))
        return fake

    def test_404_is_a_denial(self):
        real = bazaar.urllib.request.urlopen
        bazaar.urllib.request.urlopen = self._http_error(404)
        try:
            self.assertFalse(bazaar.check_purchase("pkg", "sku", "bogus"))
        finally:
            bazaar.urllib.request.urlopen = real

    def test_401_is_unknown_not_a_denial(self):
        real = bazaar.urllib.request.urlopen
        bazaar.urllib.request.urlopen = self._http_error(401, "token expired")
        try:
            with self.assertRaises(bazaar.Unknown):
                bazaar.check_purchase("pkg", "sku", "whatever")
        finally:
            bazaar.urllib.request.urlopen = real

    def test_network_failure_is_unknown(self):
        import urllib.error
        real = bazaar.urllib.request.urlopen

        def boom(url, timeout=0):
            raise urllib.error.URLError("connection refused")
        bazaar.urllib.request.urlopen = boom
        try:
            with self.assertRaises(bazaar.Unknown):
                bazaar.check_purchase("pkg", "sku", "whatever")
        finally:
            bazaar.urllib.request.urlopen = real

    def test_unlinked_client_cannot_mint_a_token(self):
        bazaar._access = self._real
        real_cfg = bazaar._config
        bazaar._config = lambda: {"client_id": "x", "client_secret": "y"}
        try:
            with self.assertRaises(bazaar.Unknown):
                bazaar._access()
        finally:
            bazaar._config = real_cfg


class BazaarFallback(unittest.TestCase):
    """Before consent, Bazaar receipts must be recorded honestly, never denied."""

    def setUp(self):
        self.conn = memdb()
        self.body = {"store": "bazaar", "product_id": "coins_large",
                     "purchase_token": "bz-x", "device_id": "d"}
        self._linked = bazaar.linked

    def tearDown(self):
        bazaar.linked = self._linked

    def test_unlinked_records_but_does_not_claim_verification(self):
        bazaar.linked = lambda: False
        code, payload = purchases.verify(self.conn, "mergedrop", "pkg", self.body, "a@b.co")
        self.assertEqual(code, 200)
        self.assertTrue(payload["granted"])
        self.assertFalse(payload["verified"])

    def test_linked_and_denied_refuses_the_receipt(self):
        bazaar.linked = lambda: True
        real = bazaar.check_purchase
        bazaar.check_purchase = lambda p, s, t: False
        try:
            code, payload = purchases.verify(
                self.conn, "mergedrop", "pkg", self.body, "a@b.co")
            self.assertEqual(code, 402)
        finally:
            bazaar.check_purchase = real

    def test_linked_but_unreachable_keeps_the_receipt(self):
        bazaar.linked = lambda: True
        real = bazaar.check_purchase

        def boom(p, s, t):
            raise bazaar.Unknown("timeout")
        bazaar.check_purchase = boom
        try:
            code, _ = purchases.verify(self.conn, "mergedrop", "pkg", self.body, "a@b.co")
            self.assertEqual(code, 503, "a timeout must not deny a paying player")
        finally:
            bazaar.check_purchase = real


class _FakeBody:
    def __init__(self, text):
        self._t = text.encode()

    def read(self):
        return self._t


if __name__ == "__main__":
    unittest.main(verbosity=2)
