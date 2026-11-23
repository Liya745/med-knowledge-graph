package com.medkg;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.jdbc.autoconfigure.DataSourceAutoConfiguration;

/**
 * 医学知识图谱系统的 Spring Boot 启动入口。
 */
@SpringBootApplication(exclude = DataSourceAutoConfiguration.class)
public class MedkgApplication {

    /**
     * 启动医学知识图谱系统。
     */
    public static void main(String[] args) {
        SpringApplication.run(MedkgApplication.class, args);
        System.out.println("med-knowledge-graph 启动成功");
    }
}
