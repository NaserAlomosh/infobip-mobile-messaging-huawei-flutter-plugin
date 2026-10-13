# App-specific release rules belong here. The plugin supplies its narrow,
# verified Huawei optional-dependency rules via consumer-rules.pro.

# SEC-01: Flutter applies this file only to optimized Release builds.
# Suppresses matching PrintStream output throughout this app, including the
# upstream AuthorizationUtils header log. Consumer apps must opt in themselves;
# do not export this policy from the plugin's consumer-rules.pro.
-assumenosideeffects class java.io.PrintStream {
    public void print(...);
    public void println(...);
}
