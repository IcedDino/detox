# Room creates WorkManager's generated database implementation by reflection.
# R8 kept the class name but removed its constructor, crashing before Flutter starts.
-keep class androidx.work.impl.WorkDatabase_Impl {
    public <init>();
}
