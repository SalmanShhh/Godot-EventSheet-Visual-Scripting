# Feedback Player - Now Called Juice Player

The Feedback Player was renamed **Juice Player** in version 0.21.0, because the node belongs to the Juice pack and now reads as part of it. This page is here so a project that still holds the older copy of the pack, whose picker section says "Feedback Player", has somewhere to land. The guide itself is the Juice Player page.

Nothing you made stops working. A scene with a `FeedbackPlayer` node loads, plays and saves as before. A script of yours that says `FeedbackPlayer` still compiles. A row you placed keeps the code it wrote. A new node is a `JuicePlayer`, which is not a `FeedbackPlayer`: if a variable of yours is typed `FeedbackPlayer` and should hold a new node, change its type to `JuicePlayer`, which the old nodes also are. To get the new row names in the picker, replace the pack's folder with the current one.
