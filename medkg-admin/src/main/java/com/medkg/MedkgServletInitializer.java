package com.medkg;

import org.springframework.boot.builder.SpringApplicationBuilder;
import org.springframework.boot.web.servlet.support.SpringBootServletInitializer;

/**
 * 将医学知识图谱系统部署到外部 Servlet 容器时使用的初始化器。
 */
public class MedkgServletInitializer extends SpringBootServletInitializer {

    /**
     * 指定外部 Servlet 容器使用的应用启动类。
     */
    @Override
    protected SpringApplicationBuilder configure(SpringApplicationBuilder application) {
        return application.sources(MedkgApplication.class);
    }
}
