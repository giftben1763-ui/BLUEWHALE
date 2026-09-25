from rest_framework import status
from rest_framework.decorators import api_view
from rest_framework.response import Response

from .routing import extract_routing

SUPPORTED_SEPS = ("sep24", "sep31")


@api_view(["POST"])
def route_deposit(request):
    """Resolve which customer account an incoming SEP-24 / SEP-31 deposit credits."""
    sep = request.data.get("sep", "sep24")
    if sep not in SUPPORTED_SEPS:
        return Response(
            {"error": f"unsupported sep '{sep}', expected one of {list(SUPPORTED_SEPS)}"},
            status=status.HTTP_400_BAD_REQUEST,
        )

    destination = request.data.get("destination")
    if not destination:
        return Response({"error": "destination is required"}, status=status.HTTP_400_BAD_REQUEST)

    result = extract_routing(
        destination,
        memo_type=request.data.get("memo_type", "none"),
        memo_value=str(request.data.get("memo", "")),
    )
    result["sep"] = sep

    if result["routing_source"] == "none":
        # Unroutable deposits are quarantined for manual review.
        result["status"] = "quarantined"
        return Response(result, status=status.HTTP_422_UNPROCESSABLE_ENTITY)

    result["status"] = "routed"
    return Response(result, status=status.HTTP_200_OK)
