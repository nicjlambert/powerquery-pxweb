# Power Query to Px Web API

Function calling Px Web API to return a dataset. API documentation: https://www.scb.se/contentassets/79c32c72783a4f67b202ad3189f921b9/api_description.pdf
Px Web API has a limit of 100,000 addresses per call. This function has two core parts:

* An internal function (funcPxWebAPI) that performs the API call. Function expects a YearIdx formatted based on Px Web's requirements.
* A loop part, where YearIdx is incremented by 1 until null records are returned, which in turn calls the API.