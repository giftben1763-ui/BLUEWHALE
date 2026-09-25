from django.test import SimpleTestCase
from django.urls import reverse
from rest_framework.test import APIClient

from deposits.routing import extract_routing

# Shared vectors from spec/vectors.json.
BASE_G = "GAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRSI"
MUXED_ID_0 = "MAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQACAAAAAAAAAAAAD672"
MUXED_2_53_PLUS_1 = "MAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQACABAAAAAAAAAAEVIG"
MUXED_MAX_UINT64 = "MAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQAD7777777777774OFW"
MUXED_BAD_UNUSED_BITS = "MAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQACAAAAAAAAAAAAD673"
CONTRACT = "CA3D5KRYM6CB7OWQ6TWYRR3Z4T7GNZLKERYNZGGA5SOAOPIFY6YQGAXE"


def codes(result):
    return [w["code"] for w in result["warnings"]]


class ExtractRoutingTests(SimpleTestCase):
    def test_g_address_with_memo_id(self):
        r = extract_routing(BASE_G, "id", "100")
        self.assertEqual(r["destination_base_account"], BASE_G)
        self.assertEqual(r["routing_id"], "100")
        self.assertEqual(r["routing_source"], "memo")
        self.assertEqual(r["warnings"], [])

    def test_g_address_with_numeric_memo_text(self):
        r = extract_routing(BASE_G, "text", "200")
        self.assertEqual(r["routing_id"], "200")
        self.assertEqual(r["routing_source"], "memo")

    def test_memo_id_above_js_safe_integer_is_preserved(self):
        r = extract_routing(BASE_G, "id", "9007199254740993")
        self.assertEqual(r["routing_id"], "9007199254740993")

    def test_leading_zeros_are_normalized_with_warning(self):
        r = extract_routing(BASE_G, "id", "007")
        self.assertEqual(r["routing_id"], "7")
        self.assertIn("NON_CANONICAL_ROUTING_ID", codes(r))

    def test_g_address_without_memo_is_unroutable(self):
        r = extract_routing(BASE_G)
        self.assertEqual(r["destination_base_account"], BASE_G)
        self.assertIsNone(r["routing_id"])
        self.assertEqual(r["routing_source"], "none")

    def test_non_numeric_memo_text_is_unroutable(self):
        r = extract_routing(BASE_G, "text", "hello")
        self.assertEqual(r["routing_source"], "none")
        self.assertIn("UNROUTABLE_MEMO", codes(r))

    def test_muxed_address_decodes_base_and_id(self):
        for m_address, expected_id in [
            (MUXED_ID_0, "0"),
            (MUXED_2_53_PLUS_1, "9007199254740993"),
            (MUXED_MAX_UINT64, "18446744073709551615"),
        ]:
            with self.subTest(m_address=m_address):
                r = extract_routing(m_address)
                self.assertEqual(r["destination_base_account"], BASE_G)
                self.assertEqual(r["routing_id"], expected_id)
                self.assertEqual(r["routing_source"], "muxed")
                self.assertEqual(r["warnings"], [])

    def test_muxed_address_ignores_external_memo(self):
        r = extract_routing(MUXED_2_53_PLUS_1, "id", "42")
        self.assertEqual(r["routing_id"], "9007199254740993")
        self.assertIn("MEMO_IGNORED_FOR_MUXED", codes(r))

    def test_lowercase_address_is_normalized(self):
        r = extract_routing(BASE_G.lower(), "id", "5")
        self.assertEqual(r["destination_base_account"], BASE_G)
        self.assertIn("NON_CANONICAL_ADDRESS", codes(r))

    def test_contract_address_is_rejected(self):
        r = extract_routing(CONTRACT, "id", "1")
        self.assertIsNone(r["destination_base_account"])
        self.assertEqual(r["routing_source"], "none")
        self.assertEqual(r["warnings"][-1]["message"], "C address is not a valid destination")

    def test_invalid_strkeys_are_rejected(self):
        for bad in [MUXED_BAD_UNUSED_BITS, "GA0CUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRSI", "not-an-address"]:
            with self.subTest(address=bad):
                r = extract_routing(bad)
                self.assertEqual(r["routing_source"], "none")
                self.assertIn("INVALID_DESTINATION", codes(r))


class RouteDepositEndpointTests(SimpleTestCase):
    """Mock SEP-24 / SEP-31 deposits posted to the routing endpoint."""

    def setUp(self):
        self.client = APIClient()
        self.url = reverse("route-deposit")

    def post(self, payload):
        return self.client.post(self.url, payload, format="json")

    def test_sep24_deposit_to_muxed_address_is_routed(self):
        resp = self.post({"sep": "sep24", "destination": MUXED_2_53_PLUS_1, "amount": "25.0"})
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp.json()["status"], "routed")
        self.assertEqual(resp.json()["routing_id"], "9007199254740993")
        self.assertEqual(resp.json()["destination_base_account"], BASE_G)

    def test_sep31_deposit_with_memo_id_is_routed(self):
        resp = self.post({"sep": "sep31", "destination": BASE_G, "memo_type": "id", "memo": "12345"})
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp.json()["sep"], "sep31")
        self.assertEqual(resp.json()["routing_source"], "memo")
        self.assertEqual(resp.json()["routing_id"], "12345")

    def test_deposit_without_memo_is_quarantined(self):
        resp = self.post({"sep": "sep24", "destination": BASE_G})
        self.assertEqual(resp.status_code, 422)
        self.assertEqual(resp.json()["status"], "quarantined")

    def test_deposit_to_contract_is_quarantined(self):
        resp = self.post({"sep": "sep31", "destination": CONTRACT, "memo_type": "id", "memo": "1"})
        self.assertEqual(resp.status_code, 422)
        self.assertIn("INVALID_DESTINATION", codes(resp.json()))

    def test_missing_destination_is_bad_request(self):
        self.assertEqual(self.post({"sep": "sep24"}).status_code, 400)

    def test_unsupported_sep_is_bad_request(self):
        self.assertEqual(self.post({"sep": "sep6", "destination": BASE_G}).status_code, 400)
